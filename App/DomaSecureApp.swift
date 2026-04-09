import SwiftUI
import ReownAppKit
import WalletConnectNetworking

@main
struct DomaSecureApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var dynamic = DynamicManager()
    @StateObject private var session = AppSession()
    @StateObject private var xmtpService = XmtpService()
    @StateObject private var themeManager = ThemeManager()
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(dynamic)
                .environmentObject(viewModel.socketConnectionManager)
                .environmentObject(xmtpService)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    handleDeeplink(url)
                }
                // XMTP is initialized explicitly during onboarding (after profile check).
                // On app relaunch, recover XMTP only if the user is already fully authenticated.
                .task {
                    // Ensure networking is connected as soon as app starts
                    try? await Networking.instance.connect()
                    
                    if let addr = dynamic.walletAddress, !addr.isEmpty, session.isAuthed {
                        initXmtp(for: addr)
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        print("[App] Foreground - Ensuring relay connection...")
                        Task {
                            try? await Networking.instance.connect()
                        }
                    }
                }
        }
    }

    private func initXmtp(for walletAddress: String) {
        guard !xmtpService.isReady else { return } // Already initialized

        // --- PRODUCTION: WalletConnect signer ---
        print("[App] Wallet connected: \(walletAddress), initializing XMTP via WalletConnect...")
        let sessions = AppKit.instance.getSessions()
        guard let activeSession = sessions.first else {
            print("[App] ⚠️ No active WalletConnect session found yet.")
            return
        }
        Task {
            do {
                try await xmtpService.initializeWithWalletConnect(
                    address: walletAddress,
                    session: activeSession
                )
                print("[App] ✅ XMTP initialized via WalletConnect")
            } catch {
                print("[App] ❌ XMTP init via WalletConnect failed: \(error)")
            }
        }
    }

    private func handleDeeplink(_ url: URL) {
        print("[App] Deep link received: \(url)")
        AppKit.instance.handleDeeplink(url)
    }
}
