//
//  XmtpService.swift
//  DomaSecure
//
//  Central XMTP client + message stream for the current conversation.
//

import Foundation
import SwiftUI
import Combine
import WalletConnectSign
import ReownAppKit
#if canImport(XMTPiOS)
import XMTPiOS
#endif

#if !canImport(XMTPiOS)
/// Minimal stub so the file compiles without XMTP SDK. Replace with real type when XMTP is added.
public struct SigningKey {}
#endif

/// Simple message model for SwiftUI
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isMine: Bool
    let createdAt: Date
    var senderDomain: String?
}

enum XmtpServiceError: LocalizedError {
    case notConnected
    case conversationNotInitialized
    case missingSigner
    case missingInboxId
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "XMTP client is not initialized or signed in."
        case .conversationNotInitialized:
            return "The conversation has not been fully initialized yet. Join it first."
        case .missingSigner:
            return "No signer available for XMTP."
        case .missingInboxId:
            return "Could not resolve inbox for this domain."
        case .generic(let msg):
            return msg
        }
    }
}

/// Wraps the XMTP `Client` and manages a *single active conversation* at a time.
@MainActor
final class XmtpService: ObservableObject {

    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var isReady: Bool = false

    /// The installation ID of the XMTP client on THIS device
    @Published private(set) var currentInstallationId: String?

    /// The Doma conversation.id currently open in the UI
    @Published private(set) var activeConversationId: String?

    /// Messages for the **active** conversation
    @Published private(set) var messages: [ChatMessage] = []

    /// Used to show small "sending..." state in composer
    @Published private(set) var isSending: Bool = false

    #if canImport(XMTPiOS)
    private(set) var client: Client?
    private var messageStreamTask: Task<Void, Never>?
    #else
    // Fallback placeholders when XMTP SDK isn't available
    private class PlaceholderClient {}
    private(set) var client: PlaceholderClient?
    private var messageStreamTask: Task<Void, Never>?
    #endif

    // Boxed sender to keep compile-time safety without XMTP types
    private struct ConversationBox {
        let sendText: (String) async throws -> String
    }

    // MARK: - Mock State
    @Published var useMock: Bool = false
    private var mockConversations: [String: [ChatMessage]] = [:] // conversationKey -> messages

    // MARK: - Public API

    /// Start the service in Mock Mode (for testing without a signer/wallet).
    func startMock() {
        print("DEBUG: XmtpService starting in MOCK mode.")
        self.useMock = true
        self.isReady = true
        self.client = nil // Ensure no real client
    }

    /// Ensure we have an XMTP client for this wallet.
    /// - Parameter signer: A SigningKey that uses your wallet (Dynamic / WalletConnect).
    func ensureClient(signer: SigningKey, dbKey: Data) async throws {
        if useMock { return } // Skip if in mock mode
        
        if client != nil {
            isReady = true
            return
        }

        #if canImport(XMTPiOS)
        isConnecting = true
        defer { isConnecting = false }

        let options = ClientOptions(
            api: .init(env: .dev),
            dbEncryptionKey: dbKey
        )

        do {
            client = try await Client.create(
                account: signer,
                options: options
            )
            isReady = true
        } catch {
            // Handle installation limit (10/10) similar to web flow
            let msg = String(describing: error)
            if msg.contains("10/10") || msg.localizedCaseInsensitiveContains("registered 10 installations") {
                // TODO: If XMTP iOS exposes inbox state + revoke APIs, call them here then retry create.
                throw error
            } else {
                throw error
            }
        }
        #else
        // XMTP SDK not available; mark as ready to avoid blocking app in dev builds
        isReady = true
        #endif
    }
    

    /// Initialize XMTP using a WalletConnect signer (prompts user in wallet to approve)
    /// Initialize XMTP using a WalletConnect signer (prompts user in wallet to approve)
    /// - Parameter isManual: If true, this was an explicit user tap; perform maintenance (like revoking old devices).
    func initializeWithWalletConnect(address: String, session: WalletConnectSign.Session, isManual: Bool = false) async throws {
        print("DEBUG: [XmtpService] initializeWithWalletConnect called for \(address)")

        #if canImport(XMTPiOS)
        if client != nil {
            print("DEBUG: [XmtpService] Client already exists. Returning.")
            isReady = true
            useMock = false
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        // 1. One-time migration: clear old XMTP database from hardcoded key mode
        let migrationKey = "xmtp_migrated_to_wc"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            print("DEBUG: [XmtpService] First WalletConnect init — clearing old hardcoded DB...")
            UserDefaults.standard.removeObject(forKey: "d_db_key_hardcoded")
            Self.clearXmtpDatabaseFiles()
            UserDefaults.standard.set(true, forKey: migrationKey)
        }

        // 2. Get or create DB encryption key (persisted in UserDefaults)
        let udKey = "d_db_key_wc_\(address.lowercased())"
        var dbKey: Data
        let hasExistingDBKey: Bool
        
        if let stored = UserDefaults.standard.data(forKey: udKey) {
            dbKey = stored
            hasExistingDBKey = true
            print("DEBUG: [XmtpService] Using stored DB key for \(address)")
        } else {
            dbKey = Data.random(length: 32)
            hasExistingDBKey = false
            UserDefaults.standard.set(dbKey, forKey: udKey)
            print("DEBUG: [XmtpService] Created & stored new DB key for \(address)")
        }

        // 3. Create signer backed by WalletConnect
        let signer = WalletConnectXMTPSigner(address: address, session: session)
        
        // 4. Client Options
        let options = ClientOptions(
            api: .init(env: .dev),
            dbEncryptionKey: dbKey
        )

        // Installation ID UserDefaults key (lives alongside the DB key)
        let installIdUDKey = "d_install_id_wc_\(address.lowercased())"

        // 5. Attempt to build or create the client
        do {
            var isNewInstallation = false
            
            if hasExistingDBKey {
                print("DEBUG: [XmtpService] Found existing DB key for \(address). Attempting to build Client from local DB...")
                do {
                    self.client = try await Client.build(
                        publicIdentity: signer.identity,
                        options: options
                    )
                    print("DEBUG: [XmtpService] ✅ XMTP client successfully built from local DB.")
                } catch {
                    print("DEBUG: [XmtpService] ⚠️ Failed to build from local DB: \(error). Falling back to Client.create...")
                    self.client = try await Self.createClientWithKeyRecovery(
                        signer: signer,
                        dbKey: &dbKey,
                        dbKeyUDKey: udKey
                    )
                    isNewInstallation = true
                }
            } else {
                print("DEBUG: [XmtpService] No existing DB key found. Calling Client.create...")
                self.client = try await Self.createClientWithKeyRecovery(
                    signer: signer,
                    dbKey: &dbKey,
                    dbKeyUDKey: udKey
                )
                isNewInstallation = true
            }
            
            // 6. Identify & persist THIS device's installation ID
            do {
                print("DEBUG: [XmtpService] Checking active installations...")
                // Refresh from network only for NEW installations or manual recovery
                let refresh = isNewInstallation || isManual
                let inboxState = try await self.client?.inboxState(refreshFromNetwork: refresh)
                if let installations = inboxState?.installations {
                    print("DEBUG: [XmtpService] Found \(installations.count) active installations.")
                    
                    if isNewInstallation {
                        // We just created a new installation — the newest one is ours
                        let newest = installations.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }.first
                        if let myId = newest?.id {
                            UserDefaults.standard.set(myId, forKey: installIdUDKey)
                            self.currentInstallationId = myId
                            print("DEBUG: [XmtpService] Stored new installation ID: \(myId)")
                        }
                    } else {
                        // Built from existing DB — read back the stored installation ID
                        if let storedId = UserDefaults.standard.string(forKey: installIdUDKey) {
                            self.currentInstallationId = storedId
                            print("DEBUG: [XmtpService] Restored installation ID from storage: \(storedId)")
                        } else {
                            // Fallback: no stored ID (upgrade from older version), pick the newest
                            let newest = installations.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }.first
                            if let myId = newest?.id {
                                UserDefaults.standard.set(myId, forKey: installIdUDKey)
                                self.currentInstallationId = myId
                                print("DEBUG: [XmtpService] Fallback: stored installation ID: \(myId)")
                            }
                        }
                    }
                    
                    // 7. Enforce Max 7 Installations (skip revoking our own)
                    // ONLY if this is a manual connection (not a recovery/build)
                    // or it's a completely new installation.
                    if (isManual || isNewInstallation) && installations.count > 7 {
                        print("DEBUG: [XmtpService] ⚠️ Installation limit exceeded (>7). Revoking oldest ones...")
                        
                        let sortedInstallations = installations.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
                        let numberToRevoke = sortedInstallations.count - 7
                        let installationsToRevoke = Array(sortedInstallations.prefix(numberToRevoke))
                            .filter { $0.id != self.currentInstallationId } // Never revoke ourselves
                        
                        let idsToRevoke = installationsToRevoke.map { $0.id }
                        print("DEBUG: [XmtpService] Revoking installations: \(idsToRevoke)")
                        try await self.client?.revokeInstallations(signingKey: signer, installationIds: idsToRevoke)
                        
                        print("DEBUG: [XmtpService] ✅ Successfully revoked oldest installations. Now under limit.")
                    }
                }
            } catch {
                print("DEBUG: [XmtpService] ⚠️ Failed to check installations: \(error)")
            }
            
            self.isReady = true
            self.useMock = false
            print("DEBUG: [XmtpService] ✅ XMTP connection fully established (installationId: \(self.currentInstallationId ?? "nil"))")
        } catch {
            print("DEBUG: [XmtpService] ❌ XMTP Init FAILED: \(error)")
            throw error
        }
        #else
        print("DEBUG: [XmtpService] XMTP SDK not available.")
        #endif
    }

    /// Attempts `Client.create`; if it fails with a PRAGMA key mismatch, clears the
    /// stale database files, generates a fresh encryption key, and retries once.
    #if canImport(XMTPiOS)
    private static func createClientWithKeyRecovery(
        signer: SigningKey,
        dbKey: inout Data,
        dbKeyUDKey: String
    ) async throws -> Client {
        let options = ClientOptions(
            api: .init(env: .dev),
            dbEncryptionKey: dbKey
        )

        print("DEBUG: [XmtpService] Creating XMTP Client with WalletConnect signer...")
        do {
            return try await Client.create(account: signer, options: options)
        } catch {
            let errorMsg = String(describing: error)
            // Detect PRAGMA key / salt mismatch (SQLCipher encrypted DB with wrong key)
            if errorMsg.contains("PRAGMA key") || errorMsg.contains("incorrect value") || errorMsg.contains("Storage error") {
                print("DEBUG: [XmtpService] ⚠️ PRAGMA key mismatch — clearing stale DB and retrying...")

                // 1. Delete all XMTP database files
                clearXmtpDatabaseFiles()

                // 2. Generate a fresh encryption key
                let freshKey = Data.random(length: 32)
                dbKey = freshKey
                UserDefaults.standard.set(freshKey, forKey: dbKeyUDKey)
                print("DEBUG: [XmtpService] Generated fresh DB key and cleared old database.")

                // 3. Retry with the fresh key
                let retryOptions = ClientOptions(
                    api: .init(env: .dev),
                    dbEncryptionKey: freshKey
                )
                return try await Client.create(account: signer, options: retryOptions)
            }
            throw error
        }
    }
    #endif

    /// Delete local XMTP database files to resolve key mismatches
    private static func clearXmtpDatabaseFiles() {
        let fileManager = FileManager.default

        // XMTP SDK may store DB files in multiple locations
        var searchDirs: [URL] = []
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            searchDirs.append(appSupport)
        }
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            searchDirs.append(documents)
        }
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            searchDirs.append(caches)
        }

        for dir in searchDirs {
            // Remove `xmtp` subdirectory if it exists
            let xmtpDir = dir.appendingPathComponent("xmtp")
            if fileManager.fileExists(atPath: xmtpDir.path) {
                try? fileManager.removeItem(at: xmtpDir)
                print("DEBUG: [XmtpService] Deleted XMTP directory: \(xmtpDir.path)")
            }

            // Remove any files containing "xmtp" or "libxmtp" in their name (e.g. .db3, .sqlite)
            if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in contents {
                    let name = file.lastPathComponent.lowercased()
                    if name.contains("xmtp") || name.contains("libxmtp") {
                        try? fileManager.removeItem(at: file)
                        print("DEBUG: [XmtpService] Deleted: \(file.lastPathComponent)")
                    }
                }
            }
        }
    }

    /// Logs out the user by clearing the client, local state, and database files.
    func logout() {
        #if canImport(XMTPiOS)
        self.client = nil
        #endif
        self.isReady = false
        self.useMock = false
        self.messages = []
        self.activeConversationId = nil
        self.messageStreamTask?.cancel()
        self.messageStreamTask = nil
        self.currentConversationBox = nil
        Self.clearXmtpDatabaseFiles()
    }

    /// Open (or create) a DM conversation to the given inboxId.
    /// - Parameters:
    ///   - inboxId: XMTP inbox ID of the peer (from your backend/domain lookup).
    ///   - conversationKey: some stable key to associate with this Doma conversation (e.g. backend `conversation.id`).
    func openDm(inboxId: String, conversationKey: String) async throws {
        if useMock {
            print("DEBUG: Mock opening DM for \(conversationKey)")
            self.activeConversationId = conversationKey
            self.messages = mockConversations[conversationKey] ?? []
            
            // Mock sender
            self.currentConversationBox = ConversationBox(sendText: { [weak self] text in
                guard let self = self else { return UUID().uuidString }
                // Simulate network delay
                try await Task.sleep(nanoseconds: 500_000_000)
                // Message is added optimistically in send(), so just verify success here
                print("DEBUG: Mock message sent to \(conversationKey): \(text)")
                
                // Simulate reply after 2 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        let reply = ChatMessage(
                            id: UUID().uuidString,
                            text: "Echo: \(text) (Mock Reply)",
                            isMine: false,
                            createdAt: Date()
                        )
                        self.messages.append(reply)
                        // Save to mock store
                        var stored = self.mockConversations[conversationKey] ?? []
                        stored.append(reply)
                        self.mockConversations[conversationKey] = stored
                    }
                }
                return UUID().uuidString
            })
            return
        }

        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }

        messageStreamTask?.cancel()
        messages = []
        activeConversationId = conversationKey

        let dm = try await client.conversations.newGroup(with: [inboxId])
        self.currentConversationBox = ConversationBox(sendText: { text in
            return try await dm.send(content: text)
        })

        let allMessages = try await dm.messages()

        self.messages = allMessages.compactMap { msg in
            guard (try? msg.encodedContent.type) == ContentTypeText else { return nil }
            guard let content: String = try? msg.content(),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ChatMessage(
                id: msg.id,
                text: content,
                isMine: false,
                createdAt: msg.sentAt
            )
        }
        .sorted { $0.createdAt < $1.createdAt }

        messageStreamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await msg in dm.streamMessages() {
                    guard (try? msg.encodedContent.type) == ContentTypeText else { continue }
                    guard let content: String = try? msg.content(),
                          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    await MainActor.run {
                        let new = ChatMessage(
                            id: msg.id,
                            text: content,
                            isMine: false,
                            createdAt: msg.sentAt
                        )
                        if !self.messages.contains(where: { $0.id == new.id }) {
                            self.messages.append(new)
                        }
                    }
                }
            } catch {
                // TODO: handle stream errors appropriately
            }
        }
        #else
        // XMTP SDK not available; reset state and surface an error
        messageStreamTask?.cancel()
        messages = []
        activeConversationId = conversationKey
        throw XmtpServiceError.generic("XMTP SDK is not integrated in this build.")
        #endif
    }

    /// Send a text message in the currently open conversation.
    func send(text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if !useMock {
            #if canImport(XMTPiOS)
            guard client != nil else { 
                print("[XmtpService] ❌ Cannot send: Client is still nil")
                throw XmtpServiceError.notConnected 
            }
            #endif
        }

        isSending = true
        defer { isSending = false }

        guard let box = currentConversationBox else {
            print("[XmtpService] ❌ Cannot send: currentConversationBox is nil (conversationKey: \(activeConversationId ?? "nil"))")
            throw XmtpServiceError.conversationNotInitialized
        }

        // Send via box (returns real ID)
        let messageId = try await box.sendText(text)

        // Optimistic UI: append message immediately with REAL ID
        let optimistic = ChatMessage(
            id: messageId,
            text: text,
            isMine: true,
            createdAt: Date()
        )
        
        // Check for duplicates before appending (in case stream beat us to it)
        if !messages.contains(where: { $0.id == messageId }) {
            messages.append(optimistic)
        }
        
        if useMock, let cid = activeConversationId {
            var stored = mockConversations[cid] ?? []
            stored.append(optimistic)
            mockConversations[cid] = stored
        }
    }

    // MARK: - Installation Management
    
    struct XMTPDevice: Hashable {
        let id: String
        let createdAt: Date
    }
    
    /// Returns the active installations for this identity.
    func getInstallationDevices() async throws -> [XMTPDevice] {
        if useMock {
            return [
                XMTPDevice(id: "mock-installation-1", createdAt: Date().addingTimeInterval(-86400)),
                XMTPDevice(id: "mock-installation-2", createdAt: Date())
            ]
        }
        
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        let state = try await client.inboxState(refreshFromNetwork: true)
        return state.installations.map {
            XMTPDevice(id: $0.id, createdAt: $0.createdAt ?? Date.distantPast)
        }
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    /// Revokes a specific installation ID manually via Settings (requires wallet signature)
    func revokeInstallationByID(_ id: String) async throws {
        if useMock { return }
        
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // Retrieve the active session to sign the revocation
        guard let session = AppKit.instance.getSessions().first,
              let address = AppKit.instance.getAddress() else {
            throw XmtpServiceError.missingSigner
        }
        
        let signer = WalletConnectXMTPSigner(address: address, session: session)
        print("DEBUG: [XmtpService] Manually revoking installation ID: \(id)...")
        try await client.revokeInstallations(signingKey: signer, installationIds: [id])
        print("DEBUG: [XmtpService] ✅ Successfully revoked installation \(id)")
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    /// Revokes all other installations except the one on this device (requires wallet signature)
    func revokeAllOtherInstallations() async throws {
        if useMock { return }
        
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // Retrieve the active session to sign the revocation
        guard let session = AppKit.instance.getSessions().first,
              let address = AppKit.instance.getAddress() else {
            throw XmtpServiceError.missingSigner
        }
        
        let signer = WalletConnectXMTPSigner(address: address, session: session)
        print("DEBUG: [XmtpService] Revoking all OTHER installations...")
        try await client.revokeAllOtherInstallations(signingKey: signer)
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }

    // MARK: - Internal

    /// Keep reference to the active conversation's send capability
    private var currentConversationBox: ConversationBox?


    // MARK: - XMTP Helpers (web parity)

    /// Check if a wallet address can be messaged on XMTP.
    func canMessage(address: String) async throws -> Bool {
        if useMock { return true }
        
        #if canImport(XMTPiOS)
        // TODO: Replace with actual XMTP iOS API when available.
        // Example (pseudocode):
        // let result = try await client?.canMessage([address])
        // return result?[address.lowercased()] == true
        return true
        #else
        return false
        #endif
    }

    /// Create or get a group conversation for a domain pair and return its id.
    /// Create or get a group conversation for a domain pair and return its id.
    func startNewChat(senderDomain: String, recipientDomain: String, recipientInboxId: String, recipientAddress: String) async throws -> String {
        let domainPair = [senderDomain, recipientDomain].sorted().joined(separator: ":")
        let groupName = "doma:\(domainPair)"
        
        if useMock {
             return groupName // In mock, we use the group name as the ID
        }

        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }

        // 1. Sync & Check for Existing Group
        try await client.conversations.sync()
        let allConversations = try await client.conversations.list()
        
        var existingGroup: XMTPiOS.Group?
        
        for conv in allConversations {
            if case .group(let g) = conv {
                // `g.name` seems to be a function: `func name() throws -> String`
                if let name = try? g.name(), name == groupName {
                    existingGroup = g
                    break
                }
            }
        }
        
        if let existing = existingGroup {
            print("DEBUG: Found existing group for \(groupName) (ID: \(existing.id))")
            try await existing.sync()
            
            // Sync to backend
            _ = try await DomaAPI.shared.syncConversation(
                id: existing.id,
                senderDomain: senderDomain,
                recipientDomain: recipientDomain
            )
            return existing.id
        }

        // 2. Create New Group (Using helper for web parity)
        print("DEBUG: Creating new group \(groupName) for \(recipientAddress)")
        let groupId = try await createGroupWithIdentifiers(addresses: [recipientAddress], name: groupName)
        
        // 3. Sync DM to Doma Backend
        _ = try await DomaAPI.shared.syncConversation(
            id: groupId,
            senderDomain: senderDomain,
            recipientDomain: recipientDomain
        )
        
        print("DEBUG: Group created and synced. ID: \(groupId)")
        return groupId
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    // ... (createGroup/addMember existing implementations) ...
    // Note: I'm not touching createGroup/addMember here unless needed, focusing on startNewChat refactor.
    // Wait, createGroup/addMember should use similar resolution if they use addresses.
    // But startNewChat is the focus.

    // ... (private helpers) ...

    /// Helper to match Web SDK's `createGroupWithIdentifiers` behavior
    /// Uses PublicIdentity (Ethereum addresses) — the SDK handles inboxId resolution internally.
    private func createGroupWithIdentifiers(addresses: [String], name: String) async throws -> String {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // Match web SDK: createGroupWithIdentifiers(memberIdentifiers, { groupName, groupDescription })
        let identities = addresses.map { addr in
            PublicIdentity(kind: .ethereum, identifier: addr)
        }
        
        print("DEBUG: Creating group with \(identities.count) identities, name: \(name)")
        
        let group = try await client.conversations.newGroupWithIdentities(
            with: identities,
            name: name,
            description: "Group created by Doma"
        )
        
        try await group.sync()
        return group.id
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    /// Create a multi-user group chat and sync to backend for ALL members.
    /// Returns (groupId, failedDomains) — failedDomains lists members whose backend sync failed (e.g. profile not set).
    func createGroup(ownerDomain: String, groupName: String, memberDomains: [String]) async throws -> (groupId: String, failedDomains: [String]) {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // 1. Resolve addresses for all members
        print("DEBUG: Creating group '\(groupName)' with members: \(memberDomains)")
        var resolvedAddresses: [String] = []
        
        for domain in memberDomains {
            do {
                let res = try await DomaAPI.shared.getOwnerByDomain(domain: domain)
                if let addr = res.owner {
                    resolvedAddresses.append(addr)
                } else {
                    print("DEBUG: Could not resolve owner address for domain: \(domain)")
                }
            } catch {
                print("DEBUG: Error resolving domain \(domain): \(error)")
            }
        }
        
        guard !resolvedAddresses.isEmpty else {
            throw XmtpServiceError.generic("No valid member addresses found to create group.")
        }
        
        // 2. Create XMTP Group (using internal helper that handles InboxID logic)
        // Note: The helper expects *new* members. The creator is implicitly included.
        let groupId = try await self.createGroupWithIdentifiers(addresses: resolvedAddresses, name: groupName)
        
        print("DEBUG: Group created. ID: \(groupId)")

        // 3. Sync to Backend for ALL participants (Owner + Members)
        // This ensures the group shows up in everyone's sidebar immediately (if they refresh)
        let allDomains = [ownerDomain] + memberDomains
        
        // Collect failures per domain
        let failedDomains = await withTaskGroup(of: String?.self) { group in
            for domain in allDomains {
                group.addTask {
                    do {
                        try await DomaAPI.shared.upsertDomainGroupConversation(
                            conversationId: groupId,
                            memberDomain: domain,
                            actorDomain: ownerDomain,
                            groupName: groupName
                        )
                        print("DEBUG: Synced group for \(domain)")
                        return nil // success
                    } catch {
                        print("DEBUG: Failed to sync group for \(domain): \(error)")
                        return domain // return the failed domain
                    }
                }
            }
            
            var failures: [String] = []
            for await result in group {
                if let failedDomain = result {
                    failures.append(failedDomain)
                }
            }
            return failures
        }
        
        return (groupId: groupId, failedDomains: failedDomains)
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    /// Add a member to an existing group and sync backend
    func addMember(groupId: String, newMemberDomain: String, actorDomain: String) async throws {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // 1. Get Group
        guard let group = try client.conversations.findGroup(groupId: groupId) else {
            throw XmtpServiceError.generic("Group not found")
        }
        
        // 2. Resolve new member address
        let ownerRes = try await DomaAPI.shared.getOwnerByDomain(domain: newMemberDomain)
        guard let address = ownerRes.owner else {
            throw XmtpServiceError.generic("Could not resolve address for \(newMemberDomain)")
        }
        
        // 3. Add to XMTP Group using identity (matches web: conversation.addMembers([inboxId]))
        let identity = PublicIdentity(kind: .ethereum, identifier: address)
        try await group.addMembersByIdentity(identities: [identity])
        try await group.sync()
        
        // 4. Sync Backend for the new member
        try await DomaAPI.shared.addGroupMember(
            conversationId: group.id,
            actorDomain: actorDomain,
            memberDomain: newMemberDomain
        )
        print("DEBUG: Added \(newMemberDomain) to group \(groupId) by actor \(actorDomain)")
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }

    /// Join an existing conversation by id and begin streaming.
    func joinConversation(groupId: String) async throws {
        if useMock {
            print("DEBUG: Mock joining conversation \(groupId)")
            // Mock logic reuse from openDm (simplified)
            self.activeConversationId = groupId
            self.messages = mockConversations[groupId] ?? []
            self.currentConversationBox = ConversationBox(sendText: { [weak self] text in
                try await Task.sleep(nanoseconds: 500_000_000)
                print("DEBUG: Mock message sent to \(groupId): \(text)")
                let id = UUID().uuidString
                self?.messages.append(ChatMessage(id: id, text: text, isMine: true, createdAt: Date()))
                return id
            })
            return
        }

        #if canImport(XMTPiOS)
        guard let client else { throw XmtpServiceError.notConnected }
        
        // 1. Sync conversations from network then find group
        print("DEBUG: [joinConversation] Syncing conversations before findGroup... (Attempt 1)")
        try await client.conversations.sync()
        
        var group = try await client.conversations.findGroup(groupId: groupId)
        
        // 2. SELF-HEALING: If group not found by ID, try to find by member domains
        if group == nil {
            print("DEBUG: [joinConversation] Group \(groupId) not found. Attempting self-healing...")
            
            do {
                let members = try await DomaAPI.shared.getGroupConversationMembers(conversationId: groupId)
                let resolvedAddresses = members.compactMap { $0.wallet }
                
                if resolvedAddresses.count == 2 {
                    // It's a DM. Try to find/recreate the group by members.
                    let myAddress = AppKit.instance.getAddress()?.lowercased()
                    let peerAddress = resolvedAddresses.first { $0.lowercased() != myAddress }
                    
                    if let peer = peerAddress {
                        print("DEBUG: [joinConversation] DM detected with peer: \(peer). Resolving via newGroup...")
                        group = try await client.conversations.newGroup(with: [peer])
                        print("DEBUG: [joinConversation] ✅ Healed DM group. New (or existing) XMTP ID: \(group?.id ?? "nil")")
                    }
                } else if !resolvedAddresses.isEmpty {
                    // Try to find by name if multiple members
                    print("DEBUG: [joinConversation] Group chat detected with \(resolvedAddresses.count) members. Syncing again...")
                    try await client.conversations.sync()
                    group = try await client.conversations.findGroup(groupId: groupId)
                }
            } catch {
                print("DEBUG: [joinConversation] ❌ Self-healing failed: \(error)")
            }
        }
        
        guard let finalGroup = group else {
             throw XmtpServiceError.generic("Group not found on XMTP network (ID: \(groupId)). Please ensure you are a member.")
        }
        
        // 3. Setup State
        self.messageStreamTask?.cancel()
        self.messages = []
        self.activeConversationId = groupId
        
        // 4. Setup Send Capability
        self.currentConversationBox = ConversationBox(sendText: { text in
            return try await finalGroup.send(content: text)
        })
        
        // 5. Load Initial Messages & Build inboxId→domain mapping
        try await finalGroup.sync()
        let allMessages = try await finalGroup.messages()
        let myInboxId = client.inboxID
        
        // Build inboxId → display name mapping using member API (returns domain, wallet, name)
        var inboxIdToName: [String: String] = [:]
        do {
            let members = try await DomaAPI.shared.getGroupConversationMembers(conversationId: groupId)
            for member in members {
                let address: String
                if let wallet = member.wallet {
                    address = wallet
                } else {
                    let ownerRes = try await DomaAPI.shared.getOwnerByDomain(domain: member.domain)
                    address = ownerRes.owner ?? ""
                }
                
                guard !address.isEmpty else { continue }
                
                let identity = PublicIdentity(kind: .ethereum, identifier: address)
                if let inboxId = try await client.inboxIdFromIdentity(identity: identity) {
                    // Use "name (domain)" format for display, or just domain if name is empty/nil
                    if let name = member.name, !name.isEmpty {
                        inboxIdToName[inboxId] = name
                    } else {
                        inboxIdToName[inboxId] = member.domain
                    }
                }
            }
        } catch {
            print("DEBUG: Failed to fetch group members: \(error)")
        }
        
        self.messages = allMessages.compactMap { msg in
            // Only show text messages — skip GroupUpdated, reactions, read receipts, etc.
            guard (try? msg.encodedContent.type) == ContentTypeText else { return nil }
            guard let content: String = try? msg.content(),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ChatMessage(
                id: msg.id,
                text: content,
                isMine: msg.senderInboxId == myInboxId,
                createdAt: msg.sentAt,
                senderDomain: inboxIdToName[msg.senderInboxId]
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
        
        // 6. Start Streaming
        self.messageStreamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await msg in finalGroup.streamMessages() {
                    // Only show text messages
                    guard (try? msg.encodedContent.type) == ContentTypeText else { continue }
                    guard let content: String = try? msg.content(),
                          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    await MainActor.run {
                        let new = ChatMessage(
                            id: msg.id,
                            text: content,
                            isMine: msg.senderInboxId == myInboxId,
                            createdAt: msg.sentAt,
                            senderDomain: inboxIdToName[msg.senderInboxId]
                        )
                        if !self.messages.contains(where: { $0.id == new.id }) {
                            self.messages.append(new)
                        }
                    }
                }
            } catch {
                print("DEBUG: Message stream error: \(error)")
            }
        }
        
        print("DEBUG: Joined group \(groupId), loaded \(messages.count) messages.")
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }

    /// Stop streaming messages for the current conversation.
    func stopStreaming() {
        messageStreamTask?.cancel()
    }
    /// Helper to resolve an address to a V3 InboxID using available SDK methods
    private func resolveTargetInboxId(address: String) async -> String? {
        #if canImport(XMTPiOS)
        guard let client else { return nil }
        
        do {
            // Priority 1: Use `newConversation` to implicitly resolve V3 InboxID
            // This works because `newConversation` handles the complex Address -> Inbox lookup.
            let conv = try await client.conversations.newConversation(with: address)
            
            switch conv {
            case .group(let g):
                try await g.sync()
                let members = try await g.members
                let myInboxId = client.inboxID
                
                // Filter to find the peer's ID
                if let peer = members.first(where: { $0.inboxId != myInboxId }) {
                    return peer.inboxId
                }
            default:
                // If it resolves to V1/V2, we might not get an InboxID easily.
                // But for V3 groups parity, we usually expect V3.
                print("DEBUG: Address resolved to legacy conversation type.")
            }
        } catch {
            print("DEBUG: Error resolving inboxId: \(error)")
            // Fallback: If `newConversation` failed (likely due to invalid ID format for 0x address),
            // assume the InboxID is simply the clean hex address.
            // This covers the error "Invalid inboxId: 0x... Inbox IDs cannot start with '0x'."
            let clean = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
            print("DEBUG: Falling back to cleaned address as InboxID: \(clean)")
            return clean
        }
        
        return nil
        #else
        return nil
        #endif
    }
}

// MARK: - Extensions

extension Data {
    static func random(length: Int) -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        return data
    }

    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var data = Data()
        data.reserveCapacity(hexString.count / 2)
        
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            if nextIndex > index {
                let byteString = hexString[index..<nextIndex]
                if let byte = UInt8(byteString, radix: 16) {
                    data.append(byte)
                }
                index = nextIndex
            } else {
                break
            }
        }
        self = data
    }
}
