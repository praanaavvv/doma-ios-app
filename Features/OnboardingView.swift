import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager

    @State private var showDomainPicker = false
    @State private var loadingDomains = false
    @State private var domainsError: String?
    @State private var domains: [String] = []

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            OrbitHeaderView()
                .frame(height: 320)
                .padding(.top, 12)

            Text("Doma Secure")
                .font(.system(size: 28, weight: .bold))

            Text(
                "Stay connected with your friends securely through our domain-based messaging service, ensuring your conversations are private and protected."
            )
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)

            VStack(spacing: 12) {

                // ✅ CONNECT WALLET (Dynamic + ASWebAuthenticationSession)
                PrimaryPillButton(
                    title: dynamic.walletAddress != nil ? "Wallet Connected" : "Connect Wallet",
                    systemIcon: "wallet.pass"
                ) {
                    dynamic.connectWallet()
                }
                .disabled(!dynamic.isReady || dynamic.isConnecting)

                // ❌ NOT READY / ERROR
                if !dynamic.isReady {
                    if let err = dynamic.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Text("Initializing…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
                }

                // 🔄 CONNECTING
                if dynamic.isConnecting {
                    ProgressView("Connecting wallet…")
                        .font(.system(size: 13))
                        .tint(.blue)
                }

                // ✅ WALLET CONNECTED
                if let addr = dynamic.walletAddress, !addr.isEmpty {
                    Text("Connected: \(addr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    PrimaryPillButton(
                        title: "Continue",
                        systemIcon: "arrow.right"
                    ) {
                        Task {
                            await fetchDomainsAndProceed(ownerAddress: addr)
                        }
                    }
                    
                    Button(action: {
                        dynamic.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 4)
                }

                // 🔄 DOMAIN LOADING
                if loadingDomains {
                    ProgressView("Fetching domains…")
                        .font(.system(size: 13))
                        .tint(.blue)
                }

                // ❌ DOMAIN ERROR
                if let domainsError, !domainsError.isEmpty {
                    Text(domainsError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 20)

        // ✅ DOMAIN PICKER
        .fullScreenCover(isPresented: $showDomainPicker) {
            DomainPickerView(domains: domains) { pickedDomain in
                session.walletAddress = dynamic.walletAddress ?? ""
                session.domains = domains
                session.activeDomain = pickedDomain
                session.isAuthed = true
            }
        }
    }

    // MARK: - Fetch domains
    @MainActor
    private func fetchDomainsAndProceed(ownerAddress: String) async {
        loadingDomains = true
        domainsError = nil

        do {
            session.walletAddress = ownerAddress

            let list = try await DomaAPI.shared.fetchDomains(owner: ownerAddress)

            guard !list.isEmpty else {
                domainsError = "No domains found for this wallet."
                session.domains = []
                loadingDomains = false
                return
            }

            domains = list
            session.domains = list

            loadingDomains = false
            showDomainPicker = true
        } catch {
            domainsError = error.localizedDescription
            session.domains = []
            loadingDomains = false
        }
    }
}

