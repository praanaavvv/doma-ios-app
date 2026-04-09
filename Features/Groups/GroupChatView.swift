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
    @State private var searchText = ""
    
    // Filter groups by name or underlying domain
    private var filteredGroups: [GroupConversation] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return viewModel.groupConversations
        }
        return viewModel.groupConversations.filter { group in
            let nameMatch = (group.metadata.name ?? "").localizedCaseInsensitiveContains(trimmed)
            let domainMatch = group.withDomain.localizedCaseInsensitiveContains(trimmed)
            return nameMatch || domainMatch
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    SearchPill(text: $searchText, onSubmit: {})
                    
                    if filteredGroups.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("No groups found")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        groupList
                    }
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
                        Image(systemName: showCreateGroup ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(showCreateGroup ? Color(.systemGray3) : .blue)
                    }
                }
            }
            .onAppear {
                Task { await viewModel.initialLoad(activeDomain: session.activeDomain) }
            }
            .onChange(of: session.activeDomain) { newDomain in
                Task { await viewModel.refreshConversations(for: newDomain) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .domaReloadGroups)) { notification in
                let convId = notification.userInfo?["conversationId"] as? String ?? "unknown"
                print("[GroupChatView] 🔄 Received domaReloadGroups for conv: \(convId), fetching new group conversations...")
                Task { await viewModel.refreshConversations(for: session.activeDomain) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .domaNewMessage)) { _ in
                Task { await viewModel.refreshConversations(for: session.activeDomain) }
            }
        }
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
                Task { await viewModel.createGroup(xmtpService: xmtpService, activeDomain: session.activeDomain) }
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
        List(filteredGroups, id: \.conversationId) { group in
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
    
    func initialLoad(activeDomain: String?) async {
        await refreshConversations(for: activeDomain)
    }
    
    func refreshConversations(for activeDomain: String?) async {
        guard let domain = activeDomain, !domain.isEmpty else {
            self.groupConversations = []
            return
        }
        do {
            print("[GroupChatViewModel] ⏳ Fetching group conversations for domain: \(domain)")
            self.groupConversations = try await DomaAPI.shared.getGroupConversations(domain: domain)
            print("[GroupChatViewModel] ✅ Fetched \(self.groupConversations.count) group conversations")
        } catch {
            print("[GroupChatViewModel] ❌ Error fetching groups: \(error)")
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
        guard memberStatus == .valid, !selectedMembers.contains(newMemberDomain) else { return }
        selectedMembers.append(newMemberDomain)
        newMemberDomain = ""
        memberStatus = .idle
    }
    
    func removeMemberFromSelection(_ member: String) {
        selectedMembers.removeAll { $0 == member }
    }
    
    func createGroup(xmtpService: XmtpService, activeDomain: String?) async {
        guard let domain = activeDomain, !domain.isEmpty else {
             createError = "No active domain selected."
             return
        }
        guard !newGroupName.isEmpty, !selectedMembers.isEmpty else { return }
        isCreating = true
        createError = nil
        defer { isCreating = false }
        
        do {
            let result = try await xmtpService.createGroup(
                ownerDomain: domain,
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
            await refreshConversations(for: domain)
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
    
    // Role Actions State
    @State private var isManagingRole = false
    @State private var actionError: String? = nil
    
    private var currentUserRole: MemberRole? {
        let activeDomain = (session.activeDomain ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !activeDomain.isEmpty else { return nil }
        
        return currentMembers.first(where: { 
            $0.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == activeDomain
        })?.role
    }
    
    private var canManageMembers: Bool {
        currentUserRole == .owner || currentUserRole == .admin
    }
    
    private var canManageAdmins: Bool {
        currentUserRole == .owner
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Members bar
            membersBar
            
            // Messages
            messagesArea
            
            // Input bar
            inputBar
        }
        .toolbar(.hidden, for: .tabBar)
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
        .onReceive(NotificationCenter.default.publisher(for: .domaReloadGroups)) { notification in
            let convId = notification.userInfo?["conversationId"] as? String
            if convId == nil || convId == group.conversationId {
                print("[GroupDetailView] 🔄 Received reload event, fetching members...")
                Task { await fetchMembers() }
            }
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
                        if let role = member.role, role != .member {
                            Text(role.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(role == .owner ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                .foregroundColor(role == .owner ? .orange : .blue)
                                .cornerRadius(4)
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
        HStack(spacing: 12) {
            TextField("Message…", text: $inputText, axis: .vertical)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6).opacity(0.8))
                .clipShape(Capsule())
                .lineLimit(1...4)
                .submitLabel(.send)
                .onSubmit {
                    Task { await sendMessage() }
                }

            if xmtpService.isSending {
                ProgressView().padding(.trailing, 2)
            } else {
                Button {
                    Task { await sendMessage() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Member Management Sheet
    
    private var memberManagementSheet: some View {
        NavigationStack {
            List {
                if let error = actionError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }
                }
                
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
                            
                            Spacer()
                            
                            if let role = member.role, role != .member {
                                Text(role.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(role == .owner ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(role == .owner ? .orange : .blue)
                                    .cornerRadius(6)
                            }
                            
                                // Show management menu dots to everyone (but gate actions inside)
                                if member.role != .owner && member.domain != session.activeDomain && !isManagingRole {
                                    Menu {
                                        if canManageMembers {
                                            Button(role: .destructive) {
                                                Task { await removeMember(domain: member.domain) }
                                            } label: {
                                                Label("Remove from group", systemImage: "trash")
                                            }
                                            
                                            Divider()
                                            
                                            if member.role == .admin {
                                                Button {
                                                    Task { await demoteAdmin(domain: member.domain) }
                                                } label: {
                                                    Label("Remove from Admin", systemImage: "arrow.down.shield")
                                                }
                                            } else {
                                                Button {
                                                    Task { await promoteAdmin(domain: member.domain) }
                                                } label: {
                                                    Label("Make Admin", systemImage: "arrow.up.shield")
                                                }
                                            }
                                        } else {
                                            // Empty or limited view for regular members
                                            Text("No actions available")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .padding(12)
                                            .background(Color.black.opacity(0.001))
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.borderless)
                                }
                        }
                    }
                }
                
                if canManageMembers {
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
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isManagingRole {
                        ProgressView().padding(.trailing, 8)
                    }
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
            async let membersTask = DomaAPI.shared.getGroupConversationMembers(conversationId: group.conversationId)
            async let adminsTask = DomaAPI.shared.getGroupAdmins(conversationId: group.conversationId)
            
            let (members, adminData) = try await (membersTask, adminsTask)
            
            // Reconcile roles using the source of truth from getGroupAdmins / metadata
            self.currentMembers = members.map { member in
                var updatedMember = member
                let domain = member.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                if let owner = adminData.owner?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), domain == owner {
                    updatedMember.role = .owner
                } else if let admins = adminData.admins, admins.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == domain }) {
                    updatedMember.role = .admin
                } else {
                    updatedMember.role = .member
                }
                return updatedMember
            }
            
            // Diagnostic logging
            print("[GroupDetailView] ✅ Fetched \(currentMembers.count) members. Admins list present: \(adminData.admins != nil)")
            for m in currentMembers {
                print("  - Domain: \(m.domain), Role: \(m.role?.rawValue ?? "nil"), CurrentUser: \(m.domain == (session.activeDomain ?? ""))")
            }
            print("[GroupDetailView] currentUserRole detected as: \(currentUserRole?.rawValue ?? "nil") (canManage: \(canManageMembers))")
            
        } catch {
            print("[GroupDetailView] ❌ Error fetching members/admins: \(error)")
        }
    }
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Ensure we are joined before sending
        if xmtpService.activeConversationId != group.conversationId {
            print("[GroupDetailView] Not joined yet. Forcing join before send...")
            await joinGroup()
        }
        
        inputText = ""
        do {
            try await xmtpService.send(text: text)
            
            // Broadcast message_sent via WebSocket to one other member (so backend validation passes)
            let myDomain = session.webSocket.domain
            if let recipient = currentMembers.first(where: { $0.domain != myDomain }) {
                session.webSocket.sendMessageEvent(to: recipient.domain, conversationId: group.conversationId)
            }
            
        } catch {
            print("Error sending message: \(error)")
            inputText = text
        }
    }
    
    func addMember() async {
        guard let activeDomain = session.activeDomain else { return }
        guard !addMemberDomain.isEmpty else { return }
        isAddingMember = true
        actionError = nil
        defer { isAddingMember = false }
        
        do {
            try await xmtpService.addMember(groupId: group.conversationId, newMemberDomain: addMemberDomain, actorDomain: activeDomain)
            addMemberDomain = ""
            await fetchMembers()
        } catch {
            print("Failed to add member: \(error)")
            actionError = "Failed to add member: \(error.localizedDescription)"
        }
    }
    
    func removeMember(domain: String) async {
        guard let activeDomain = session.activeDomain else { return }
        isManagingRole = true
        actionError = nil
        defer { isManagingRole = false }
        do {
            try await DomaAPI.shared.removeGroupMember(conversationId: group.conversationId, requesterDomain: activeDomain, memberDomain: domain)
            await fetchMembers()
        } catch {
            actionError = "Failed to remove member: \(error.localizedDescription)"
        }
    }
    
    func promoteAdmin(domain: String) async {
        guard let activeDomain = session.activeDomain else { return }
        isManagingRole = true
        actionError = nil
        defer { isManagingRole = false }
        do {
            try await DomaAPI.shared.promoteGroupAdmin(conversationId: group.conversationId, actorDomain: activeDomain, targetAdminDomain: domain)
            await fetchMembers()
        } catch {
            actionError = "Failed to promote admin: \(error.localizedDescription)"
        }
    }
    
    func demoteAdmin(domain: String) async {
        guard let activeDomain = session.activeDomain else { return }
        isManagingRole = true
        actionError = nil
        defer { isManagingRole = false }
        do {
            try await DomaAPI.shared.demoteGroupAdmin(conversationId: group.conversationId, ownerDomain: activeDomain, adminDomain: domain)
            await fetchMembers()
        } catch {
            actionError = "Failed to demote admin: \(error.localizedDescription)"
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
