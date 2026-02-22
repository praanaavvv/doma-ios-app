//
//  GroupChatView.swift
//  DomaSecure
//
//  Created for Group Chat Feature.
//

import SwiftUI
import Combine

struct GroupChatView: View {
    @EnvironmentObject var xmtpService: XmtpService
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = GroupChatViewModel()
    @State private var showCreateGroup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Domain selector header
                domainSelector
                
                // Create group expandable section
                if showCreateGroup {
                    createGroupSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                // Group conversations list
                if viewModel.groupConversations.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showCreateGroup.toggle()
                        }
                    } label: {
                        Image(systemName: showCreateGroup ? "xmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: showCreateGroup
                                            ? [Color(.systemGray3), Color(.systemGray3)]
                                            : [.blue, .blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                    }
                }
            }
            .onAppear {
                Task { await viewModel.initialLoad(walletAddress: session.walletAddress) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .domaReloadGroups)) { _ in
                Task { await viewModel.refreshConversations() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .domaNewMessage)) { _ in
                Task { await viewModel.refreshConversations() }
            }
        }
    }
    
    // MARK: - Domain Selector
    
    private var domainSelector: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Text("Active domain")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Picker("Domain", selection: $viewModel.selectedDomain) {
                ForEach(viewModel.domains, id: \.self) { domain in
                    Text(domain).tag(domain)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
            .onChange(of: viewModel.selectedDomain) { _ in
                Task { await viewModel.refreshConversations() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Create Group Section
    
    private var createGroupSection: some View {
        VStack(spacing: 14) {
            // Group name input
            HStack(spacing: 10) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Group name", text: $viewModel.newGroupName)
                    .font(.system(size: 15))
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Add member input
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Member domain…", text: $viewModel.newMemberDomain)
                    .font(.system(size: 15))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.newMemberDomain) { newValue in
                        viewModel.validateMemberDomain(newValue)
                    }
                
                // Status indicator
                Group {
                    if viewModel.memberStatus == .checking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if viewModel.memberStatus == .valid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    } else if viewModel.memberStatus == .invalid {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.memberStatus)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.addMemberToSelection()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.memberStatus == .valid ? .blue : Color(.systemGray4))
                }
                .disabled(viewModel.memberStatus != .valid)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Selected members chips
            if !viewModel.selectedMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedMembers, id: \.self) { member in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Text(String(member.prefix(1)).uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    )
                                
                                Text(member)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.removeMemberFromSelection(member)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Circle().fill(Color(.systemGray5)))
                                }
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                            )
                        }
                    }
                }
            }
            
            // Create button
            Button {
                Task { await viewModel.createGroup(xmtpService: xmtpService) }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    }
                    Text(viewModel.isCreating ? "Creating…" : "Create Group")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: (viewModel.newGroupName.isEmpty || viewModel.selectedMembers.isEmpty)
                            ? [Color(.systemGray4), Color(.systemGray4)]
                            : [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isCreating || viewModel.newGroupName.isEmpty || viewModel.selectedMembers.isEmpty)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Group List
    
    private var groupList: some View {
        List(viewModel.groupConversations, id: \.conversationId) { group in
            ZStack {
                NavigationLink(destination: GroupDetailView(group: group, viewModel: viewModel)) {
                    EmptyView()
                }
                .opacity(0)
                
                groupRow(group)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
    
    private func groupRow(_ group: GroupConversation) -> some View {
        HStack(spacing: 14) {
            // Group avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.metadata.name ?? "Unnamed Group")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                    Text(group.withDomain)
                        .lineLimit(1)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text("No groups yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text("Tap + to create your first group")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ViewModel

@MainActor
class GroupChatViewModel: ObservableObject {
    @Published var domains: [String] = []
    @Published var selectedDomain: String = ""
    @Published var groupConversations: [GroupConversation] = []
    
    // Create Group State
    @Published var newGroupName: String = ""
    @Published var newMemberDomain: String = ""
    @Published var selectedMembers: [String] = []
    @Published var memberStatus: MemberStatus = .idle
    @Published var isCreating: Bool = false
    @Published var createError: String?
    
    enum MemberStatus {
        case idle, checking, valid, invalid
    }
    
    // Validation Debounce Task
    private var validationTask: Task<Void, Never>?
    
    func initialLoad(walletAddress: String?) async {
        guard let owner = walletAddress, !owner.isEmpty else {
            print("Error: No wallet address available for fetching domains.")
            return
        }
        
        do {
            self.domains = try await DomaAPI.shared.fetchDomains(owner: owner)
            if let first = self.domains.first, selectedDomain.isEmpty {
                selectedDomain = first
                await refreshConversations()
            }
        } catch {
            print("Error fetching domains: \(error)")
        }
    }
    
    func refreshConversations() async {
        guard !selectedDomain.isEmpty else { return }
        do {
            self.groupConversations = try await DomaAPI.shared.getGroupConversations(domain: selectedDomain)
        } catch {
            print("Error fetching groups: \(error)")
        }
    }
    
    func validateMemberDomain(_ domain: String) {
        validationTask?.cancel()
        if domain.isEmpty {
            memberStatus = .idle
            return
        }
        memberStatus = .checking
        validationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            do {
                let res = try await DomaAPI.shared.getOwnerByDomain(domain: domain)
                memberStatus = (res.owner != nil) ? .valid : .invalid
            } catch {
                memberStatus = .invalid
            }
        }
    }
    
    func addMemberToSelection() {
        guard memberStatus == .valid, !selectedMembers.contains(newMemberDomain), newMemberDomain != selectedDomain else { return }
        selectedMembers.append(newMemberDomain)
        newMemberDomain = ""
        memberStatus = .idle
    }
    
    func removeMemberFromSelection(_ member: String) {
        selectedMembers.removeAll { $0 == member }
    }
    
    func createGroup(xmtpService: XmtpService) async {
        guard !newGroupName.isEmpty, !selectedMembers.isEmpty else { return }
        isCreating = true
        createError = nil
        defer { isCreating = false }
        
        do {
            let result = try await xmtpService.createGroup(
                ownerDomain: selectedDomain,
                groupName: newGroupName,
                memberDomains: selectedMembers
            )
            
            // Show warning if some members failed to sync (e.g. profile not set)
            if !result.failedDomains.isEmpty {
                let failed = result.failedDomains.joined(separator: ", ")
                createError = "Group created, but failed to add: \(failed). They may need to set up their profile first."
            }
            
            newGroupName = ""
            selectedMembers = []
            await refreshConversations()
        } catch {
            createError = "Failed to create group: \(error.localizedDescription)"
            print("Failed to create group: \(error)")
        }
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {
    let group: GroupConversation
    @ObservedObject var viewModel: GroupChatViewModel
    @EnvironmentObject var xmtpService: XmtpService
    @EnvironmentObject var session: AppSession
    
    @State private var inputText: String = ""
    @State private var currentMembers: [GroupMember] = []
    @State private var showMemberSheet = false
    
    // Add Member State
    @State private var isAddingMember = false
    @State private var addMemberDomain = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Members bar
            membersBar
            
            // Messages
            messagesArea
            
            // Input bar
            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(group.metadata.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMemberSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 13))
                        if !currentMembers.isEmpty {
                            Text("\(currentMembers.count)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showMemberSheet) {
            memberManagementSheet
        }
        .onAppear {
            Task {
                await joinGroup()
                await fetchMembers()
            }
        }
        .onDisappear {
            xmtpService.stopStreaming()
        }
    }
    
    // MARK: - Members Bar
    
    private var membersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(currentMembers) { member in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(member.name ?? member.domain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        if member.name != nil {
                            Text(member.domain)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(.systemBackground)))
                }
                
                if currentMembers.isEmpty {
                    Text("Loading members…")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Messages Area
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(xmtpService.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: xmtpService.messages) { _ in
                if let last = xmtpService.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.isMine {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("You")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(msg.text)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                        .cornerRadius(6, corners: .bottomRight)
                }
            } else {
                // Sender avatar
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String((msg.senderDomain ?? "?").prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(msg.senderDomain ?? "Unknown")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(msg.text)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                        .cornerRadius(6, corners: .bottomLeft)
                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $inputText, axis: .vertical)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    Task { await sendMessage() }
                }
            
            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.isEmpty
                        ? Color(.systemGray4)
                        : Color.blue
                    )
            }
            .disabled(inputText.isEmpty || xmtpService.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Member Management Sheet
    
    private var memberManagementSheet: some View {
        NavigationStack {
            List {
                Section("Members") {
                    ForEach(currentMembers) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.5), .purple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String((member.name ?? member.domain).prefix(1)).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name ?? member.domain)
                                    .font(.system(size: 15, weight: .medium))
                                if member.name != nil {
                                    Text(member.domain)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("Add Member") {
                    HStack(spacing: 10) {
                        TextField("Domain…", text: $addMemberDomain)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button {
                            Task { await addMember() }
                        } label: {
                            if isAddingMember {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Add")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        addMemberDomain.isEmpty
                                        ? Color(.systemGray4)
                                        : Color.blue
                                    )
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(addMemberDomain.isEmpty || isAddingMember)
                    }
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showMemberSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Actions
    
    func joinGroup() async {
        do {
            try await xmtpService.joinConversation(groupId: group.conversationId)
        } catch {
            print("Error joining group: \(error)")
        }
    }
    
    func fetchMembers() async {
        do {
            currentMembers = try await DomaAPI.shared.getGroupConversationMembers(conversationId: group.conversationId)
        } catch {
            print("Error fetching members: \(error)")
        }
    }
    
    func sendMessage() async {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        do {
            try await xmtpService.send(text: text)
            
            // Broadcast message_sent via WebSocket
            session.webSocket.sendMessageEvent(to: "", conversationId: group.conversationId)
            
        } catch {
            print("Error sending message: \(error)")
            inputText = text
        }
    }
    
    func addMember() async {
        guard !addMemberDomain.isEmpty else { return }
        isAddingMember = true
        defer { isAddingMember = false }
        
        do {
            try await xmtpService.addMember(groupId: group.conversationId, newMemberDomain: addMemberDomain)
            addMemberDomain = ""
            await fetchMembers()
        } catch {
            print("Failed to add member: \(error)")
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorners(radius: radius, corners: corners))
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
