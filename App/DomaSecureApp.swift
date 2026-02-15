import SwiftUI

@main
struct DomaSecureApp: App {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var dynamic = DynamicManager()
    @StateObject private var session = AppSession()
    @StateObject private var xmtpService = XmtpService()   // ⬅️ NEW

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(dynamic)
                .environmentObject(viewModel.socketConnectionManager)
                .environmentObject(xmtpService)            // ⬅️ NEW
                .onOpenURL { url in
                    handleDeeplink(url)
                }
                .task {
                    // Start with hardcoded key for testing
                    print("App launched: Initializing XMTP with HARDCODED key")
                    do {
                        try await xmtpService.initializeWithPrivateKey(DynamicManager.hardcodedPrivateKey)
                    } catch {
                        print("Failed to init XMTP with hardcoded key: \(error)")
                        // Fallback to mock if needed, or just crash/log
                        xmtpService.startMock()
                    }
                }
        }
    }
}

private func handleDeeplink(_ url: URL) {
    // TODO: Wire this to your app's real deep link handler.
    // This placeholder prevents build errors when AppKit (or a custom type) isn't available.
    #if os(iOS)
    // Example: route via NotificationCenter or your app router
    // NotificationCenter.default.post(name: .didReceiveDeeplink, object: url)
    #elseif os(macOS)
    // If you have a macOS-specific handler, call it here.
    #else
    // Other platforms: no-op
    #endif
}
