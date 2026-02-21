import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager

    enum OnboardingState {
        case connect
        case checkingProfile
        case createProfile
        case checkingDomains
        case ready(String) // wallet connnected
        case error(String)
    }

    @State private var currentState: OnboardingState = .connect
    @State private var profileNameInput: String = ""
    @State private var showDomainPicker = false
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
                if case .connect = currentState {
                    PrimaryPillButton(
                        title: dynamic.walletAddress != nil ? "Wallet Connected" : "Connect Wallet",
                        systemIcon: "wallet.pass"
                    ) {
                        dynamic.connectWallet()
                    }
                    .disabled(!dynamic.isReady || dynamic.isConnecting)
                }

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

                // CHECKING PROFILE / DOMAINS
                if case .checkingProfile = currentState {
                    ProgressView("Checking profile…")
                        .font(.system(size: 13))
                        .tint(.blue)
                }
                
                if case .checkingDomains = currentState {
                    ProgressView("Fetching domains…")
                        .font(.system(size: 13))
                        .tint(.blue)
                }

                // 🆕 CREATE PROFILE
                if case .createProfile = currentState {
                    VStack(spacing: 12) {
                        Text("Create Profile")
                            .font(.headline)
                        
                        TextField("Enter your name", text: $profileNameInput)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 24)
                            .autocorrectionDisabled()
                        
                        Button {
                            Task {
                                await createProfileAndProceed()
                            }
                        } label: {
                            Text("Save Profile")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 24)
                        .disabled(profileNameInput.isEmpty)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }

                // ✅ READY TO CONTINUE (Profile OK)
                if case .ready(let addr) = currentState {
                    Text("Connected: \(addr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    PrimaryPillButton(
                        title: "Continue",
                        systemIcon: "arrow.right"
                    ) {
                        if let addr = dynamic.walletAddress {
                             Task { await checkProfileAndProceed(ownerAddress: addr) }
                        }
                    }
                    
                    Button(action: {
                        dynamic.disconnect()
                        currentState = .connect
                    }) {
                        Text("Disconnect")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 4)
                }

                // ❌ ERROR
                if case .error(let msg) = currentState {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button("Retry") {
                        // If wallet is connected, try flow again
                        if let addr = dynamic.walletAddress {
                            Task { await checkProfileAndProceed(ownerAddress: addr) }
                        } else {
                            currentState = .connect
                        }
                    }
                }
            }
            .padding(.top, 6)
            // Listen for wallet connection
            .onChange(of: dynamic.walletAddress) { newValue in
                if let addr = newValue, !addr.isEmpty {
                    // Update state to ready if connected, but don't auto-proceed
                    // If we are in connect state, we just stay there or we can explicitely go to ready
                    // But wait, my logic above uses `case .ready(let addr)` to show the "Connected: addr" UI.
                    // So we definitely need to switch to .ready when wallet connects.
                    
                    if case .connect = currentState {
                        currentState = .ready(addr)
                    }
                } else {
                    currentState = .connect
                }
            }
            .onAppear {
                if let addr = dynamic.walletAddress, !addr.isEmpty {
                    currentState = .ready(addr)
                }
            }

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
    // MARK: - Flow Logic
    
    @MainActor
    private func checkProfileAndProceed(ownerAddress: String) async {
        currentState = .checkingProfile
        
        do {
            // 1. Fetch wallet data
            let data = try await DomaAPI.shared.fetchWalletData(wallet: ownerAddress)
            
            if data.status == "not set" {
                // 2a. Profile needs setup
                currentState = .createProfile
            } else {
                // 2b. Profile exists (or newly created), fetch domains
                await fetchDomains(ownerAddress: ownerAddress)
            }
        } catch {
            currentState = .error("Failed to check profile: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func createProfileAndProceed() async {
        guard let addr = dynamic.walletAddress, !profileNameInput.isEmpty else { return }
        
        currentState = .checkingProfile // reuse checking spinner
        
        do {
            let res = try await DomaAPI.shared.setupProfile(wallet: addr, name: profileNameInput)
            // proceed
            await fetchDomains(ownerAddress: addr)
        } catch {
            currentState = .error("Setup failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func fetchDomains(ownerAddress: String) async {
        currentState = .checkingDomains
        
        do {
            session.walletAddress = ownerAddress // update session
            
            let list = try await DomaAPI.shared.fetchDomains(owner: ownerAddress)
            
            domains = list
            session.domains = list
            
            // If domains exist, we can show picker.
            // If empty, we might want to show error or let them pick (empty list -> maybe just show empty state in picker?)
            // The original code showed error if empty. Let's stick to that but maybe more graceful later.
            if list.isEmpty {
                currentState = .error("No domains found for this wallet.")
                return
            }
            
            // Success -> Ready state
            currentState = .ready(ownerAddress)
            showDomainPicker = true // Auto-trigger or let user click continue? Original code auto-triggered.
            // User flow: Connect -> Check/Setup -> Fetch -> [Auto Picker] sounds good.
        } catch {
            currentState = .error("Failed to fetch domains: \(error.localizedDescription)")
            session.domains = []
        }
    }
}

