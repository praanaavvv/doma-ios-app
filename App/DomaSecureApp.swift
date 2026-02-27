import SwiftUI
import ReownAppKit

@main
struct DomaSecureApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var dynamic = DynamicManager()
    @StateObject private var session = AppSession()
    @StateObject private var xmtpService = XmtpService()
    @StateObject private var themeManager = ThemeManager()

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
                // Initialize XMTP explicitly when the user taps "Sign & Connect" across the app
                // .onChange(of: dynamic.walletAddress) { newAddress in
                //     guard let addr = newAddress, !addr.isEmpty else { return }
                //     initXmtp(for: addr)
                // }
                // Also init XMTP on launch if wallet was recovered from previous session
                // .task {
                //     if let addr = dynamic.walletAddress, !addr.isEmpty {
                //         initXmtp(for: addr)
                //     }
                // }
        }
    }

    private func initXmtp(for walletAddress: String) {
        guard !xmtpService.isReady else { return } // Already initialized
        print("[App] Wallet address: \(walletAddress), initializing XMTP with hardcoded key...")

        Task {
            // do {
            //     // ✅ DEV MODE: Use hardcoded private key directly (no wallet approval needed)
            //     try await xmtpService.initializeWithPrivateKey(DynamicManager.hardcodedPrivateKey)
            //     print("[App] ✅ XMTP initialized with hardcoded key")
            // } catch {
            //     print("[App] ❌ XMTP init failed: \(error)")
            // }
        }

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
}

private func handleDeeplink(_ url: URL) {
    print("[App] Deep link received: \(url)")
    AppKit.instance.handleDeeplink(url)
}
