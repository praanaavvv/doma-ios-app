import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @EnvironmentObject private var xmtp: XmtpService
    @Environment(\.openURL) private var openURL
    
    @State private var profileStatus: ProfileStatus = .loading
    @State private var profileName: String = ""
    @State private var inputName: String = ""
    @State private var isSyncing = false
    
    // Edit Profile state
    @State private var showEditNameAlert = false
    @State private var editNameInput = ""
    
    enum ProfileStatus: Equatable {
        case loading, notSet, ok, error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Top title
                    HStack {
                        Text("Settings")
                            .font(.system(size: 22, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Profile Section
                    if case .notSet = profileStatus {
                        VStack(spacing: 12) {
                            Text("Create Profile")
                                .font(.headline)
                            
                            TextField("Enter your name", text: $inputName)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            
                            Button {
                                Task { await createProfile() }
                            } label: {
                                if isSyncing {
                                    ProgressView()
                                } else {
                                    Text("Save Profile")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .disabled(inputName.isEmpty || isSyncing)
                        }
                        .padding(16)
                        .background(Color(.systemGray6).opacity(0.7))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                        
                    } else {
                        // Profile card (Loading or OK or Error)
                        ProfileCard(
                            name: profileStatus == .ok ? profileName : nil,
                            wallet: session.walletAddress,
                            isLoading: isStatusLoading
                        )
                        .padding(.horizontal, 16)
                        
                        if case .error(let msg) = profileStatus {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                        }
                    }

                    // Sections
                    SettingsSection(title: "Account") {
                        Button {
                            if case .ok = profileStatus {
                                editNameInput = profileName
                            } else {
                                editNameInput = ""
                            }
                            showEditNameAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "person.crop.circle")
                                            .foregroundStyle(.secondary)
                                    )

                                Text("Edit Profile Name")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "pencil")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Divider().padding(.leading, 60),
                            alignment: .bottom
                        )
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "paintbrush")
                                            .foregroundStyle(.secondary)
                                    )

                                Text("Appearance")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Divider().padding(.leading, 60),
                            alignment: .bottom
                        )
                        NavigationLink {
                            InstallationsView()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "cpu")
                                            .foregroundStyle(.secondary)
                                    )

                                Text("XMTP Devices")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    SettingsSection(title: "Domains") {
                        Button {
                            Task { await syncProfile() }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(.blue)
                                    )
                                
                                Text("Sync Domains")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.blue)
                                
                                Spacer()
                                
                                if isSyncing {
                                    ProgressView()
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSyncing)
                        .overlay(
                            Divider().padding(.leading, 60),
                            alignment: .bottom
                        )
                    }
                    .padding(.horizontal, 16)

                    SettingsSection(title: "Support") {
                        SettingsLinkRow(icon: "questionmark.circle", title: "FAQ") {
                            if let url = URL(string: "https://docs.doma.xyz/faq") {
                                openURL(url)
                            }
                        }
                        SettingsLinkRow(icon: "envelope", title: "Contact Support") {
                            if let url = URL(string: "https://d3inc.atlassian.net/servicedesk/customer/portal/3") {
                                openURL(url)
                            }
                        }
                        SettingsLinkRow(icon: "doc.text", title: "Terms of Service") {
                            if let url = URL(string: "https://doma.xyz/terms") {
                                openURL(url)
                            }
                        }
                        SettingsLinkRow(icon: "hand.raised", title: "Privacy Policy") {
                            if let url = URL(string: "https://doma.xyz/privacy") {
                                openURL(url)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    SettingsSection(title: "Danger Zone") {
                        Button {
                            Task {
                                xmtp.hardReset()
                                await dynamic.disconnect()
                                session.walletAddress = nil
                                session.activeDomain = nil
                                session.domains = []
                                session.isAuthed = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hard Reset")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.red)
                                    Text("Clears all local identity and history")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    // Logout
                    Button(role: .destructive) {
                        Task {
                            xmtp.logout()
                            await dynamic.disconnect()
                            session.walletAddress = nil
                            session.activeDomain = nil
                            session.domains = []
                            session.isAuthed = false
                        }
                    } label: {
                        Text("Log out")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    Spacer(minLength: 22)
                }
                .padding(.bottom, 100)
            }
            .alert("Edit Profile Name", isPresented: $showEditNameAlert) {
                TextField("New Name", text: $editNameInput)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task { await editProfileName() }
                }
            } message: {
                Text("Enter a new name for your profile.")
            }
        }
        .task(id: session.walletAddress) {
            await loadProfile()
        }
    }
    
    private var isStatusLoading: Bool {
        if case .loading = profileStatus { return true }
        return false
    }

    private func loadProfile() async {
        guard let wallet = session.walletAddress else {
            profileStatus = .notSet
            return
        }
        
        profileStatus = .loading
        do {
            let data = try await DomaAPI.shared.fetchWalletData(wallet: wallet)
            if data.status == "not set" {
                profileStatus = .notSet
            } else {
                profileName = data.name ?? "User"
                profileStatus = .ok
                // Update session domains if available
                if let domains = data.domains {
                    session.domains = domains
                }
            }
        } catch {
            profileStatus = .error(error.localizedDescription)
        }
    }

    private func createProfile() async {
        guard let wallet = session.walletAddress, !inputName.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let res = try await DomaAPI.shared.setupProfile(wallet: wallet, name: inputName)
            profileName = res.name
            session.domains = res.domains
            profileStatus = .ok
        } catch {
            profileStatus = .error("Setup failed: \(error.localizedDescription)")
        }
    }
    
    private func syncProfile() async {
        guard let wallet = session.walletAddress else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let res = try await DomaAPI.shared.syncWallet(wallet: wallet)
            if res.status == "ok" {
                await session.refreshDomains()
            }
        } catch {
            print("Sync failed: \(error)")
        }
    }

    private func editProfileName() async {
        guard let wallet = session.walletAddress, !editNameInput.isEmpty else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let _ = try await DomaAPI.shared.editProfile(wallet: wallet, name: editNameInput)
            // Fetch the profile fresh to re-render the UI
            await loadProfile()
        } catch {
            print("Edit profile failed: \(error)")
        }
    }
}

// MARK: - Components

private struct ProfileCard: View {
    let name: String?
    let wallet: String?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay(Text("🦁"))

            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                     Text("Loading...")
                        .font(.system(size: 16, weight: .bold))
                        .redacted(reason: .placeholder)
                } else if let name = name {
                    Text(name)
                        .font(.system(size: 16, weight: .bold))
                    if let wallet = wallet {
                        Text(shortAddress(wallet))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No Profile")
                        .font(.system(size: 16, weight: .bold))
                    Text("Connect wallet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private func shortAddress(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemGray6).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        NavigationLink {
            SettingsDetailPlaceholderView(title: title)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(.secondary)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            Divider().padding(.leading, 60),
            alignment: .bottom
        )
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(.secondary)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            Divider().padding(.leading, 60),
            alignment: .bottom
        )
    }
}

// MARK: - Placeholder destination (renamed to avoid redeclaration)

private struct SettingsDetailPlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text(title)
                .font(.system(size: 22, weight: .bold))

            Text("UI coming with backend integration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

