import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    
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

                    // Profile card
                    ProfileCard()
                        .padding(.horizontal, 16)

                    // Sections
                    SettingsSection(title: "Account") {
                        SettingsRow(icon: "person.crop.circle", title: "My Profile")
                        SettingsRow(icon: "lock.shield", title: "Security")
                        SettingsRow(icon: "bell", title: "Notifications")
                    }
                    .padding(.horizontal, 16)

                    SettingsSection(title: "Domains") {
                        SettingsRow(icon: "globe", title: "Manage Domains")
                        SettingsRow(icon: "wrench.and.screwdriver", title: "DNS Setup Help")
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

                    // Logout
                    Button(role: .destructive) {
                        // UI-only for now
                    } label: {
                        Text("Log out")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    Spacer(minLength: 22)
                }
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Components

private struct ProfileCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay(Text("🦁"))

            VStack(alignment: .leading, spacing: 4) {
                Text("Pranav")
                    .font(.system(size: 16, weight: .bold))
                Text("@pranav.doma")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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

