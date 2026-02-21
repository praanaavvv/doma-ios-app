//
//  ChatDetailView.swift
//  DomaSecure
//
//  Domain chat view – XMTP-driven (frontend send/stream). No backend send.
//

import SwiftUI

struct ChatDetailView: View {
    let conversation: ConversationItem
    var showOwnerChanged: Bool = false

    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var xmtpService: XmtpService

    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if showOwnerChanged {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Owner change for this chat and...")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            // Messages scroll (from XMTP service)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(xmtpService.messages) { msg in
                            HStack {
                                if msg.isMine {
                                    Spacer(minLength: 40)
                                    MessageBubble(text: msg.text, isMine: true)
                                } else {
                                    MessageBubble(text: msg.text, isMine: false)
                                    Spacer(minLength: 40)
                                }
                            }
                            .id(msg.id)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 12)
                }
                .onChange(of: xmtpService.messages.count) { _ in
                    if let lastId = xmtpService.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Composer (uses XMTP service send)
            HStack(spacing: 8) {
                TextField("Message \(conversation.domain)…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await sendMessage() }
                    }

                if xmtpService.isSending {
                    ProgressView().padding(.trailing, 2)
                }

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                        .padding(8)
                        .foregroundColor(.blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.all, 12)
        }
        .navigationTitle(conversation.domain)
        .navigationBarTitleDisplayMode(.inline)
        .task { await openIfNeeded() }
        .refreshable { await openIfNeeded(force: true) }
    }

    // MARK: - XMTP open + send

    private func openIfNeeded(force: Bool = false) async {
        if !force, xmtpService.activeConversationId == conversation.id { return }
        print("[ChatDetail] Opening conversation: \(conversation.id), domain: \(conversation.domain)")
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            try await xmtpService.joinConversation(groupId: conversation.id)
            print("[ChatDetail] ✅ Successfully joined conversation: \(conversation.id)")
            await MainActor.run { isLoading = false }
        } catch {
            print("[ChatDetail] ❌ Failed to open conversation: \(error)")
            await MainActor.run {
                isLoading = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        print("[ChatDetail] Sending message: '\(text)' to conversation: \(conversation.id)")
        print("[ChatDetail] XMTP ready: \(xmtpService.isReady), activeConvoId: \(xmtpService.activeConversationId ?? "nil"), useMock: \(xmtpService.useMock)")
        do {
            try await xmtpService.send(text: text)
            print("[ChatDetail] ✅ Message sent successfully")
            await MainActor.run { inputText = "" }
        } catch {
            print("[ChatDetail] ❌ Failed to send message: \(error)")
            await MainActor.run {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - UI bubble

fileprivate struct MessageBubble: View {
    let text: String
    let isMine: Bool

    var body: some View {
        Text(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isMine ? Color.blue.opacity(0.85) : Color(.systemGray5))
            )
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}
