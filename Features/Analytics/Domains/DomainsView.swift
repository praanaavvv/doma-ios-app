import SwiftUI

struct DomainsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @Environment(\.openURL) private var openURL

    @State private var domainItems: [DomainItem] = []
    @State private var isLoadingItems = false
    @State private var onboardingDomain: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                // Profile avatar removed (user request)

                Spacer()

                Text("My Domains")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "AFAFAF"))

                Spacer()
                
                // Plus button
                Button {
                     if let url = URL(string: "https://doma.xyz/") {
                         openURL(url)
                     }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            // MARK: - Add New Domain Button
            Button {
                if let url = URL(string: "https://doma.xyz/") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Add new domain")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "F3F4F6")) // Very light gray/white
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // MARK: - Content
            if let err = session.domainsError {
                Spacer()
                Text(err)
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                Spacer()
            } else if session.isLoadingDomains {
                Spacer()
                ProgressView("Loading domains…")
                Spacer()
            } else if session.domains.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No domains found for this wallet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(domainItems, id: \.domain) { item in
                            DomainRowCard(
                                domain: item.domain,
                                isConfigured: item.messagingEnabled,
                                statusText: statusText(for: item),
                                isLoading: onboardingDomain == item.domain,
                                onConfigure: {
                                    Task { await configureDomain(item) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            // MARK: - ⚠️ TEMPORARY: Sync hardcoded address from DynamicManager
            if let addr = dynamic.walletAddress, session.walletAddress != addr {
                session.walletAddress = addr
            }
            await session.refreshDomains()
            await loadDomainItems()
        }
        .refreshable {
            // MARK: - ⚠️ TEMPORARY: Sync hardcoded address from DynamicManager
            if let addr = dynamic.walletAddress, session.walletAddress != addr {
                session.walletAddress = addr
            }
            await session.refreshDomains()
            await loadDomainItems()
        }
    }

    private func loadDomainItems() async {
        guard let owner = session.walletAddress, !owner.isEmpty else { return }
        await MainActor.run { isLoadingItems = true }
        defer { Task { await MainActor.run { isLoadingItems = false } } }
        do {
            let items = try await DomaAPI.shared.fetchDomainItems(owner: owner)
            await MainActor.run { self.domainItems = items }
        } catch {
            await MainActor.run { session.domainsError = error.localizedDescription }
        }
    }

    private func configureDomain(_ item: DomainItem) async {
        guard let owner = session.walletAddress, !owner.isEmpty else { return }
        await MainActor.run { onboardingDomain = item.domain }
        defer { Task { await MainActor.run { onboardingDomain = nil } } }
        do {
            try await DomaAPI.shared.onboardDomain(domain: item.domain, owner: owner, messagingEnabled: true, consentMode: "auto_accept", feeMode: "none")
            await loadDomainItems()
        } catch {
            await MainActor.run { session.domainsError = error.localizedDescription }
        }
    }

    private func statusText(for item: DomainItem) -> String {
        if item.messagingEnabled { return "Messaging Ready" }
        switch item.verificationStatus.lowercased() {
        case "failed": return "Verification failed"
        case "pending": return "Needs Configuration"
        default: return "Needs Configuration"
        }
    }
}

// MARK: - Domain Row Card
struct DomainRowCard: View {
    let domain: String
    let isConfigured: Bool
    let statusText: String
    let isLoading: Bool
    let onConfigure: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
                    .background(Color(.white))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(domain)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "1B1B1B"))
                        .tracking(-0.56)

                    Text(domainIdentifier)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(statusColor)
            }
            .padding(16)

            // Always show button for testing/reconfiguration
            Button(action: onConfigure) {
                HStack {
                    if isLoading { ProgressView().scaleEffect(0.8).tint(.white) }
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "F9FAFB")) // Light gray background
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        // Removed border stroke
    }

    private var domainIdentifier: String {
        let prefix = domain.prefix(2).lowercased()
        return String(prefix)
    }

    private var isFailed: Bool {
        statusText.lowercased().contains("failed")
    }
    
    private var buttonTitle: String {
        if isFailed { return "Retry" }
        if isConfigured { return "Reconfigure DNS" }
        return "Configure DNS"
    }

    private var statusColor: Color {
        if isConfigured { return Color(hex: "2ABC7E") } // Green
        if isFailed { return .red }
        return .orange
    }
}

#Preview {
    DomainsView()
        .environmentObject(AppSession())
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

