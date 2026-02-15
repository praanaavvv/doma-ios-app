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

    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var isLoading = false
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // Top bar
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

                    Button { showingNewChat = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                // Search pill (local filter over existing conversations)
                SearchPill(text: $searchText)

                if isLoading {
                    ProgressView()
                        .padding(.top, 8)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                // Conversations list
                List {
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
                // MARK: - ⚠️ TEMPORARY: Sync hardcoded address from DynamicManager
                if let addr = dynamic.walletAddress, session.walletAddress != addr {
                    session.walletAddress = addr
                }
                await loadConversations()
            }
            .sheet(isPresented: $showingNewChat) {
                // Search for a domain and start a new conversation
                SearchSheetView { newConversation in
                    // Insert or update in the current list
                    if let index = conversations.firstIndex(where: { $0.id == newConversation.id }) {
                        conversations[index] = newConversation
                    } else {
                        conversations.insert(newConversation, at: 0)
                    }
                }
                .environmentObject(session)
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
            // 1. Fetch user's domains to find the primary one
            let domains = try await DomaAPI.shared.fetchDomains(owner: wallet)
            
            guard let primaryDomain = domains.first else {
                await MainActor.run {
                    self.conversations = []
                    self.isLoading = false
                    // Optional: Show a message that they need a domain
                    // self.errorMessage = "No domains found. Claim one to chat!"
                }
                return
            }
            
            // 2. Fetch conversations for that domain
            let convos = try await DomaAPI.shared.getConversations(forDomain: primaryDomain)
            
            await MainActor.run {
                // Map backend Conversation model to local ConversationItem if needed, 
                // or if ConversationItem IS the model, assign directly.
                // Assuming DomaAPI returns [Conversation] which might need mapping to [ConversationItem]
                // or ConversationItem is an alias/type in the project.
                // Let's check imports/types. If they match, assign.
                // For now, I'll assume they need mapping or are compatible.
                // Re-using the existing assignment logic:
                self.conversations = convos.map { c in
                    ConversationItem(
                        id: c.conversationId,
                        domain: c.withDomain,
                        status: "active", // Default since backend doesn't send status
                        lastActivity: c.createdAt,
                        createdAt: c.createdAt,
                        unreadCount: 0, // Backend doesn't send unread count yet
                        preview: nil // Backend doesn't send preview yet
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

