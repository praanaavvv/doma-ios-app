//
//  XmtpService.swift
//  DomaSecure
//
//  Central XMTP client + message stream for the current conversation.
//

import Foundation
import SwiftUI
import Combine
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
}

enum XmtpServiceError: LocalizedError {
    case notConnected
    case missingSigner
    case missingInboxId
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "XMTP client is not connected."
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

    /// The Doma conversation.id currently open in the UI
    @Published private(set) var activeConversationId: String?

    /// Messages for the **active** conversation
    @Published private(set) var messages: [ChatMessage] = []

    /// Used to show small "sending..." state in composer
    @Published private(set) var isSending: Bool = false

    #if canImport(XMTPiOS)
    private var client: Client?
    private var messageStreamTask: Task<Void, Never>?
    #else
    // Fallback placeholders when XMTP SDK isn't available
    private class PlaceholderClient {}
    private var client: PlaceholderClient?
    private var messageStreamTask: Task<Void, Never>?
    #endif

    // Boxed sender to keep compile-time safety without XMTP types
    private struct ConversationBox {
        let sendText: (String) async throws -> String
    }

    // MARK: - Mock State
    @Published var useMock: Bool = true // Default to TRUE to avoid race conditions in hardcoded mode
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
    
    /// Initialize with a hardcoded private key (Testing/Dev mode)
    func initializeWithPrivateKey(_ keyHex: String) async throws {
        print("DEBUG: [XmtpService] initializeWithPrivateKey called.")
        
        #if canImport(XMTPiOS)
        if client != nil {
            print("DEBUG: [XmtpService] Client already exists. Returning.")
            isReady = true
            return
        }
        
        isConnecting = true
        defer { isConnecting = false }
        
        // 1. Get or Create a DB Encryption Key for this hardcoded user
        // Note: For production, store this in Keychain. For this hardcoded test, UserDefaults is fine.
        let udKey = "d_db_key_hardcoded"
        var dbKey: Data
        if let stored = UserDefaults.standard.data(forKey: udKey) {
            dbKey = stored
            print("DEBUG: [XmtpService] Using existing DB key. (Bytes: \(dbKey.count))")
        } else {
            dbKey = Data.random(length: 32)
            UserDefaults.standard.set(dbKey, forKey: udKey)
            print("DEBUG: [XmtpService] Generated new DB key. (Bytes: \(dbKey.count))")
        }
        
        print("DEBUG: [XmtpService] Processing hex key (Length: \(keyHex.count))...")
        let keyData = Data(hex: keyHex)
        print("DEBUG: [XmtpService] Key Data bytes: \(keyData.count)")
        
        if keyData.count != 32 {
             print("DEBUG: [XmtpService] WARNING: Key data length is \(keyData.count), expected 32 bytes for typical private key.")
        }

        print("DEBUG: [XmtpService] Creating PrivateKey object...")
        let keys: PrivateKey
        do {
            keys = try PrivateKey(keyData)
            print("DEBUG: [XmtpService] PrivateKey created successfully.")
        } catch {
            print("DEBUG: [XmtpService] Failed to create PrivateKey: \(error)")
            throw error
        }

        // 2. Pass the dbEncryptionKey to enable persistence
        let options = ClientOptions(
            api: .init(env: .dev),
            dbEncryptionKey: dbKey
        )
        
        print("DEBUG: [XmtpService] Creating XMTP Client (env: dev)...")
        do {
            self.client = try await Client.create(account: keys, options: options)
            self.isReady = true
            self.useMock = false
        } catch {
             print("DEBUG: [XmtpService] Client.create FAILED: \(error)")
             throw error
        }
        #else
        print("DEBUG: [XmtpService] XMTP SDK not available (canImport failed).")
        #endif
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

        // Assume we don't have client.inboxId, so omit isMine or use placeholder false
        self.messages = allMessages.map { msg in
            ChatMessage(
                id: msg.id,
                text: (try? msg.content()) ?? "",
                isMine: false,  // Ownership check omitted due to no client.inboxId
                createdAt: msg.sentAt
            )
        }
        .sorted { $0.createdAt < $1.createdAt }

        messageStreamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await msg in dm.streamMessages() {
                    await MainActor.run {
                        let new = ChatMessage(
                            id: msg.id,
                            text: (try? msg.content()) ?? "",
                            isMine: false, // Ownership check omitted
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
            guard client != nil else { throw XmtpServiceError.notConnected }
            #endif
        }

        isSending = true
        defer { isSending = false }

        guard let box = currentConversationBox else {
            throw XmtpServiceError.notConnected
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
    
    /// Create a multi-user group chat and sync to backend for ALL members
    func createGroup(ownerDomain: String, groupName: String, memberDomains: [String]) async throws -> String {
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
        
        // Using TaskGroup to parallelize backend syncs
        await withTaskGroup(of: Void.self) { group in
            for domain in allDomains {
                group.addTask {
                    do {
                        try await DomaAPI.shared.upsertDomainGroupConversation(
                            domain: domain,
                            conversationId: groupId,
                            groupName: groupName
                        )
                        print("DEBUG: Synced group for \(domain)")
                    } catch {
                        print("DEBUG: Failed to sync group for \(domain): \(error)")
                    }
                }
            }
        }
        
        return groupId
        #else
        throw XmtpServiceError.generic("XMTP SDK not integrated.")
        #endif
    }
    
    /// Add a member to an existing group and sync backend
    func addMember(groupId: String, newMemberDomain: String) async throws {
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
        try await DomaAPI.shared.upsertDomainGroupConversation(
            domain: newMemberDomain,
            conversationId: group.id,
            groupName: "Group"
        )
        print("DEBUG: Added \(newMemberDomain) to group \(groupId)")
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
        
        // 1. Find existing Group
        guard let group = try await client.conversations.findGroup(groupId: groupId) else {
             throw XmtpServiceError.generic("Group not found")
        }
        
        // 2. Setup State
        self.messageStreamTask?.cancel()
        self.messages = []
        self.activeConversationId = groupId
        
        // 3. Setup Send Capability
        self.currentConversationBox = ConversationBox(sendText: { text in
            return try await group.send(content: text)
        })
        
        // 4. Load Initial Messages
        try await group.sync()
        let allMessages = try await group.messages()
        let myInboxId = client.inboxID
        
        self.messages = allMessages.compactMap { msg in
            guard let content: String = try? msg.content() else { return nil }
            return ChatMessage(
                id: msg.id,
                text: content,
                isMine: msg.senderInboxId == myInboxId,
                createdAt: msg.sentAt
            )
        }
        .sorted { $0.createdAt < $1.createdAt }
        
        // 5. Start Streaming
        self.messageStreamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await msg in group.streamMessages() {
                    guard let content: String = try? msg.content() else { continue }
                    await MainActor.run {
                        let new = ChatMessage(
                            id: msg.id,
                            text: content,
                            isMine: msg.senderInboxId == myInboxId,
                            createdAt: msg.sentAt
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
