//
//  SearchSheetView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 23/12/25.
//  Updated for hardcoded wallet testing mode.
//

import Foundation
import SwiftUI

struct SearchSheetView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @EnvironmentObject private var xmtp: XmtpService
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    /// Called when a new or existing conversation has been resolved from a domain search.
    let onConversationStarted: ((ConversationItem) -> Void)?
    

    init(onConversationStarted: ((ConversationItem) -> Void)? = nil) {
        self.onConversationStarted = onConversationStarted
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search bar pill
            SearchPill(text: $query, onSubmit: {
                Task {
                    await performSearch()
                }
            })

            if isSearching {
                ProgressView("Searching…")
                    .padding(.top, 12)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            } else {
                Text("Type a domain (e.g. alice.doma) to start a chat.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Spacer()

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSearching {
                Button {
                    Task {
                        await performSearch()
                    }
                } label: {
                    Text("Start chat with \(query)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            // Sync wallet from DynamicManager if needed
            if let addr = dynamic.walletAddress, session.walletAddress != addr {
                session.walletAddress = addr
            }
        }
    }

    // MARK: - Actions

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Sync wallet address from dynamic manager if needed
        if session.walletAddress == nil || session.walletAddress?.isEmpty == true {
            if let addr = dynamic.walletAddress {
                await MainActor.run {
                    session.walletAddress = addr
                }
            }
        }

        guard let wallet = session.walletAddress, !wallet.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Connect a wallet first to start chatting."
            }
            return
        }

        await MainActor.run {
            self.isSearching = true
            self.errorMessage = nil
        }
        
        // Ensure we have an active domain to send FROM
        if session.activeDomain == nil {
            await session.refreshDomains()
            if let first = session.domains.first {
                await MainActor.run {
                    session.activeDomain = first
                }
            }
        }
        
        guard let senderDomain = session.activeDomain else {
             await MainActor.run {
                 self.isSearching = false
                 self.errorMessage = "You need a Doma domain to start a chat."
             }
             return
        }

        do {
            // 1) Validate domain via /domains/owner (like the web frontend)
            let ownerResponse = try await DomaAPI.shared.getOwnerByDomain(domain: trimmed)
            guard let ownerAddress = ownerResponse.owner, !ownerAddress.isEmpty else {
                throw SimpleError(message: "Domain not found.")
            }
            
            // 2) Create XMTP Conversation & Sync Backend
            // We pass ownerAddress. XmtpService will resolve the InboxId from it.
            let recipientInboxId = ""
            
            let conversationId = try await xmtp.startNewChat(
                senderDomain: senderDomain,
                recipientDomain: trimmed,
                recipientInboxId: recipientInboxId,
                recipientAddress: ownerAddress
            )
            
            // 3) Construct Item manually since we succeeded
            let newConversation = ConversationItem(
                id: conversationId,
                domain: trimmed,
                status: "active",
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date()),
                unreadCount: 0,
                preview: "New conversation"
            )

            // 4) Proceed to the chat
            await MainActor.run {
                self.isSearching = false
                self.onConversationStarted?(newConversation)
                self.dismiss()
            }
            
        } catch {
            await MainActor.run {
                self.isSearching = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - SearchPill

struct SearchPill: View {
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            
                .foregroundStyle(.secondary)

            TextField("Search here…", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit {
                    onSubmit?()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
}
