//
//  ChatsView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//  Updated to integrate backend conversations + domain search.
//

import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @EnvironmentObject private var xmtp: XmtpService

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSearchingDomain = false
    @State private var errorMessage: String?
    @State private var conversations: [ConversationItem] = []

    // Filter conversations by domain or preview text
    private var filteredConversations: [ConversationItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return conversations }
        return conversations.filter { convo in
            convo.domain.localizedCaseInsensitiveContains(trimmed)
            || (convo.preview ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Show "Start chat" row when query looks like a domain and isn't already in the list
    private var showNewChatOption: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // If there's already an exact-match conversation, don't offer "start new"
        let alreadyExists = conversations.contains { $0.domain.lowercased() == trimmed.lowercased() }
        return !alreadyExists
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // Top bar — no + button
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .overlay(Text("🦁"))

                    Spacer()

                    Text("Chats")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 34, height: 34)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Search pill — dual purpose: filter existing + search new domains
                SearchPill(text: $searchText, onSubmit: {
                    Task { await startChatWithDomain() }
                })

                if isLoading || isSearchingDomain {
                    ProgressView(isSearchingDomain ? "Starting chat…" : "Loading…")
                        .padding(.top, 8)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                // Conversations list
                List {
                    // "Start new chat" row when typing a domain
                    if showNewChatOption && !isSearchingDomain {
                        Button {
                            Task { await startChatWithDomain() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.message.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start chat with **\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))**")
                                        .font(.system(size: 15))
                                    Text("Search as domain")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    ForEach(filteredConversations) { convo in
                        NavigationLink {
                            ChatDetailView(conversation: convo)
                        } label: {
                            ChatRowView(conversation: convo)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .task {
                if let addr = dynamic.walletAddress, session.walletAddress != addr {
                    session.walletAddress = addr
                }
                await loadConversations()
            }
        }
    }

    // MARK: - Start new chat from search bar

    private func startChatWithDomain() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Sync wallet address
        if session.walletAddress == nil || session.walletAddress?.isEmpty == true {
            if let addr = dynamic.walletAddress {
                await MainActor.run { session.walletAddress = addr }
            }
        }

        guard let wallet = session.walletAddress, !wallet.isEmpty else {
            await MainActor.run { self.errorMessage = "Connect a wallet first to start chatting." }
            return
        }

        await MainActor.run {
            self.isSearchingDomain = true
            self.errorMessage = nil
        }

        // Ensure active domain
        if session.activeDomain == nil {
            await session.refreshDomains()
            if let first = session.domains.first {
                await MainActor.run { session.activeDomain = first }
            }
        }

        guard let senderDomain = session.activeDomain else {
            await MainActor.run {
                self.isSearchingDomain = false
                self.errorMessage = "You need a Doma domain to start a chat."
            }
            return
        }

        do {
            // 1. Validate domain
            let ownerResponse = try await DomaAPI.shared.getOwnerByDomain(domain: trimmed)
            guard let ownerAddress = ownerResponse.owner, !ownerAddress.isEmpty else {
                throw SimpleError(message: "Domain not found.")
            }

            // 2. Create XMTP Conversation
            let conversationId = try await xmtp.startNewChat(
                senderDomain: senderDomain,
                recipientDomain: trimmed,
                recipientInboxId: "",
                recipientAddress: ownerAddress
            )

            // 3. Build local ConversationItem
            let newConversation = ConversationItem(
                id: conversationId,
                domain: trimmed,
                status: "active",
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                createdAt: ISO8601DateFormatter().string(from: Date()),
                unreadCount: 0,
                preview: "New conversation"
            )

            await MainActor.run {
                self.isSearchingDomain = false
                self.searchText = ""
                // Insert at top or update
                if let index = conversations.firstIndex(where: { $0.id == newConversation.id }) {
                    conversations[index] = newConversation
                } else {
                    conversations.insert(newConversation, at: 0)
                }
            }
        } catch {
            await MainActor.run {
                self.isSearchingDomain = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Data loading

    private func loadConversations() async {
        guard let wallet = session.walletAddress, !wallet.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Connect a wallet to see your chats."
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let domains = try await DomaAPI.shared.fetchDomains(owner: wallet)
            
            guard let primaryDomain = domains.first else {
                await MainActor.run {
                    self.conversations = []
                    self.isLoading = false
                }
                return
            }
            
            let convos = try await DomaAPI.shared.getConversations(forDomain: primaryDomain)
            
            await MainActor.run {
                self.conversations = convos.map { c in
                    ConversationItem(
                        id: c.conversationId,
                        domain: c.withDomain,
                        status: "active",
                        lastActivity: c.createdAt,
                        createdAt: c.createdAt,
                        unreadCount: 0,
                        preview: nil
                    )
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Row view

struct ChatRowView: View {
    let conversation: ConversationItem

    private func formattedTime(from iso: String?) -> String {
        guard
            let iso,
            let date = ISO8601DateFormatter().date(from: iso)
        else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("🟢")
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.domain)
                    .font(.system(size: 16, weight: .semibold))

                Text(conversation.preview ?? "No messages yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime(from: conversation.lastActivity))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }
}

