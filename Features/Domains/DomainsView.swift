import SwiftUI

struct DomainsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @Environment(\.openURL) private var openURL

    @State private var isSyncing = false
    @State private var onboardingDomain: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                // Profile avatar removed (user request)

                Spacer()

                Text("My Domains")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()
                
                // Sync button
                Button {
                    Task { await syncDomains() }
                } label: {
                    if isSyncing {
                        ProgressView().scaleEffect(0.8)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                .disabled(isSyncing)
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
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.1))
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
                        ForEach(session.domains, id: \.self) { domainStr in
                            DomainRowCard(
                                domain: domainStr,
                                isActive: session.activeDomain == domainStr,
                                onConnect: {
                                    session.activeDomain = domainStr
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
            // Sync connected wallet address from DynamicManager
            if let addr = dynamic.walletAddress, session.walletAddress != addr {
                session.walletAddress = addr
            }
            await session.refreshDomains()
        }
        .refreshable {
            // Sync connected wallet address from DynamicManager
            if let addr = dynamic.walletAddress, session.walletAddress != addr {
                session.walletAddress = addr
            }
            await session.refreshDomains()
        }
    }

    private func syncDomains(force: Bool = false) async {
        guard let owner = session.walletAddress, !owner.isEmpty else { return }
        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }
        do {
            let res = try await DomaAPI.shared.syncWallet(wallet: owner)
            if res.status == "ok" {
                await session.refreshDomains()
                await MainActor.run {
                    if session.activeDomain == nil, let first = session.domains.first {
                        session.activeDomain = first
                    }
                }
            }
        } catch {
            await MainActor.run { session.domainsError = error.localizedDescription }
        }
    }
}

// MARK: - Domain Row Card
struct DomainRowCard: View {
    let domain: String
    let isActive: Bool
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(domain)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .tracking(-0.56)

                    Text(domainIdentifier)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)

            Button(action: onConnect) {
                HStack {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                    Text(isActive ? "Connected" : "Connect")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                // Use a green color if connected, else blue
                .background(isActive ? Color(hex: "28DC0F") : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isActive) // Disable button if already connected
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var domainIdentifier: String {
        let prefix = domain.prefix(2).lowercased()
        return String(prefix)
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

