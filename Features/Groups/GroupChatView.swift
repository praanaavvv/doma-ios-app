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
    
    var body: some View {
        NavigationStack {
            VStack {
                // Domain Selector
                HStack {
                    Text("Your Domain:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Picker("Domain", selection: $viewModel.selectedDomain) {
                        ForEach(viewModel.domains, id: \.self) { domain in
                            Text(domain).tag(domain)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedDomain) { newValue in
                        Task { await viewModel.refreshConversations() }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Create Group Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("CREATE GROUP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    TextField("Group Name", text: $viewModel.newGroupName)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        TextField("Add member domain...", text: $viewModel.newMemberDomain)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .onChange(of: viewModel.newMemberDomain) { newValue in
                                viewModel.validateMemberDomain(newValue)
                            }
                        
                        if viewModel.memberStatus == .checking {
                            ProgressView()
                        } else if viewModel.memberStatus == .valid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if viewModel.memberStatus == .invalid {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        
                        Button {
                            viewModel.addMemberToSelection()
                        } label: {
                            Image(systemName: "plus")
                                .padding(8)
                                .background(viewModel.memberStatus == .valid ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.memberStatus != .valid)
                    }
                    
                    // Selected Members Chips
                    if !viewModel.selectedMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.selectedMembers, id: \.self) { member in
                                    HStack(spacing: 4) {
                                        Text(member)
                                            .font(.caption)
                                        Button {
                                            viewModel.removeMemberFromSelection(member)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.createGroup(xmtpService: xmtpService)
                        }
                    } label: {
                        HStack {
                            if viewModel.isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(viewModel.isCreating ? "Creating..." : "Create Group")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((viewModel.newGroupName.isEmpty || viewModel.selectedMembers.isEmpty) ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isCreating || viewModel.newGroupName.isEmpty || viewModel.selectedMembers.isEmpty)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Group List
                List(viewModel.groupConversations, id: \.conversationId) { group in
                    NavigationLink(destination: GroupDetailView(group: group, viewModel: viewModel)) {
                        VStack(alignment: .leading) {
                            Text(group.metadata.name ?? "Unnamed Group")
                                .font(.headline)
                            Text("Created by \(group.withDomain)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Groups")
            .onAppear {
                Task { await viewModel.initialLoad(walletAddress: session.walletAddress) }
            }
        }
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
        defer { isCreating = false }
        
        do {
            _ = try await xmtpService.createGroup(
                ownerDomain: selectedDomain,
                groupName: newGroupName,
                memberDomains: selectedMembers
            )
            
            newGroupName = ""
            selectedMembers = []
            await refreshConversations()
        } catch {
            print("Failed to create group: \(error)")
        }
    }
}

// MARK: - Detail View

struct GroupDetailView: View {
    let group: GroupConversation
    @ObservedObject var viewModel: GroupChatViewModel
    @EnvironmentObject var xmtpService: XmtpService
    
    @State private var inputText: String = ""
    @State private var currentMembers: [String] = []
    
    // Add Member State
    @State private var isAddingMember = false
    @State private var addMemberDomain = ""
    
    var body: some View {
        VStack {
            // Chat Header Info
            HStack {
                Text(currentMembers.isEmpty ? "Loading members..." : "Members: \(currentMembers.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                Spacer()
                
                // Add Member UI
                HStack {
                    TextField("Add domain...", text: $addMemberDomain)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .autocapitalization(.none)
                    
                    Button {
                        Task { await addMember() }
                    } label: {
                        Text("Add")
                            .font(.caption)
                            .padding(6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .disabled(addMemberDomain.isEmpty || isAddingMember)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(xmtpService.messages) { msg in
                            HStack {
                                if msg.isMine {
                                    Spacer()
                                    Text(msg.text)
                                        .padding(10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                        .padding(.trailing, 8)
                                        // Specific styling for own messages
                                } else {
                                    VStack(alignment: .leading) {
                                        // Sender name logic would go here if we had inboxId mapping
                                        // Text(msg.senderName).font(.caption2)
                                        Text(msg.text)
                                            .padding(10)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                    }
                                    .padding(.leading, 8)
                                    Spacer()
                                }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: xmtpService.messages) { _ in
                    if let last = xmtpService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Input Area
            HStack {
                TextField("Message \(group.metadata.name ?? "Group")...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await sendMessage() }
                    }
                
                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(inputText.isEmpty || xmtpService.isSending)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationTitle(group.metadata.name ?? "Group")
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
    
    func joinGroup() async {
        do {
            try await xmtpService.joinConversation(groupId: group.conversationId)
        } catch {
            print("Error joining group: \(error)")
        }
    }
    
    func fetchMembers() async {
        do {
            let memberData = try await DomaAPI.shared.getGroupConversationMembers(conversationId: group.conversationId)
            // API returns array of strings (domains) or objects? 
            // DomaAPI definition: `func getGroupConversationMembers(conversationId: String) async throws -> [String]`
            // So it returns [String].
            currentMembers = memberData
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
        } catch {
            print("Error sending message: \(error)")
            inputText = text // restore on failure
        }
    }
    
    func addMember() async {
        guard !addMemberDomain.isEmpty else { return }
        isAddingMember = true
        defer { isAddingMember = false }
        
        do {
            try await xmtpService.addMember(groupId: group.conversationId, newMemberDomain: addMemberDomain)
            addMemberDomain = ""
            // Refresh members
            await fetchMembers()
        } catch {
            print("Failed to add member: \(error)")
        }
    }
}
