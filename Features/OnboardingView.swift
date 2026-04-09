import SwiftUI
import ReownAppKit

struct OnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager
    @EnvironmentObject private var xmtpService: XmtpService
    @EnvironmentObject private var socketManager: SocketConnectionManager
    
    enum OnboardingState {
        case connect
        case checkingProfile
        case createProfile
        case checkingDomains
        case settlingConnection(String)
        case promptXmtpSign(String, [String])
        case initializingXmtp
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
                                // 🔐 INITIALIZING XMTP
                if case .initializingXmtp = currentState {
                    VStack(spacing: 8) {
                        ProgressView("Initializing secure messaging…")
                            .font(.system(size: 13))
                            .tint(.blue)
                        Text("Please approve the signature in your wallet if prompted.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
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
                if dynamic.walletAddress != nil, case .ready(let addr) = currentState {
                    VStack(spacing: 12) {
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
                            Task {
                                await dynamic.disconnect()
                                await MainActor.run { currentState = .connect }
                            }
                        }) {
                            Text("Disconnect")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // ⌛ SETTLING
                if case .settlingConnection = currentState {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finalizing wallet connection...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 🔐 PROMPT XMTP SIGN
                if case .promptXmtpSign(let addr, let list) = currentState {
                    VStack(spacing: 16) {
                        Text("Secure Messaging")
                            .font(.headline)
                        
                        Text("Please sign in with your wallet to enable secure, end-to-end encrypted messaging.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        if !socketManager.socketConnected {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Connecting to wallet service...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 8)
                        }

                        PrimaryPillButton(
                            title: "Sign & Connect",
                            systemIcon: "signature"
                        ) {
                            Task { await initXmtpAndProceed(ownerAddress: addr, domainList: list) }
                        }
                        .disabled(!socketManager.socketConnected)
                    }
                }
                
                // ❌ ERROR
                if case .error(let msg) = currentState {
                    VStack(spacing: 12) {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Button("Retry") {
                            if let addr = dynamic.walletAddress {
                                currentState = .settlingConnection(addr)
                                Task {
                                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                                    await checkProfileAndProceed(ownerAddress: addr)
                                }
                            } else {
                                currentState = .connect
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
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
                        // 3.5s settlement delay to let SDK/Relay stabilize after wallet connection
                        currentState = .settlingConnection(addr)
                        Task {
                            try? await Task.sleep(nanoseconds: 3_500_000_000)
                            if case .settlingConnection(let currentAddr) = currentState {
                                await checkProfileAndProceed(ownerAddress: currentAddr)
                            }
                        }
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
    
    // MARK: - Flow Logic
    
    /// Initialize XMTP, then proceed to domain selection.
    /// If the user already has a local DB key, Client.build succeeds silently (no wallet prompt).
    /// Otherwise Client.create triggers a WalletConnect signature request.
    @MainActor
    private func initXmtpAndProceed(ownerAddress: String, domainList: [String]) async {
        currentState = .initializingXmtp
        
        // Grab the active WalletConnect session
        let sessions = AppKit.instance.getSessions()
        guard let activeSession = sessions.first else {
            currentState = .error("No active wallet session found. Please reconnect.")
            return
        }
        
        do {
            if !xmtpService.isReady {
                try await xmtpService.initializeWithWalletConnect(
                    address: ownerAddress,
                    session: activeSession,
                    isManual: true
                )
            }
            print("[Onboarding] ✅ XMTP ready")
            
            // Now proceed to domain selection
            if domainList.count == 1 {
                session.activeDomain = domainList[0]
                session.isAuthed = true
            } else {
                currentState = .ready(ownerAddress)
                showDomainPicker = true
            }
        } catch {
            currentState = .error("Secure messaging setup failed: \(error.localizedDescription)")
        }
    }
    
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
                // 2b. Profile exists, fetch domains
                let list = data.domains ?? []
                session.walletAddress = ownerAddress
                domains = list
                session.domains = list
                
                if list.isEmpty {
                    currentState = .error("No domains found for this wallet.")
                    return
                }
                
                // 3. Prompt XMTP sign before showing domain picker
                // Skip if already ready (e.g. recovered from previous session)
                if xmtpService.isReady {
                    if list.count == 1 {
                        session.activeDomain = list[0]
                        session.isAuthed = true
                    } else {
                        currentState = .ready(ownerAddress)
                        showDomainPicker = true
                    }
                } else {
                    currentState = .promptXmtpSign(ownerAddress, list)
                }
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
            let list = res.domains
            session.walletAddress = addr
            domains = list
            session.domains = list
            
            if list.isEmpty {
                currentState = .error("No domains found for this wallet.")
                return
            }
            
            // Prompt XMTP sign before showing domain picker
            // Skip if already ready
            if xmtpService.isReady {
                if list.count == 1 {
                    session.activeDomain = list[0]
                    session.isAuthed = true
                } else {
                    currentState = .ready(addr)
                    showDomainPicker = true
                }
            } else {
                currentState = .promptXmtpSign(addr, list)
            }
        } catch {
            currentState = .error("Setup failed: \(error.localizedDescription)")
        }
    }
}



