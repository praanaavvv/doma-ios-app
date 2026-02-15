import Foundation
import Combine
// MARK: - ⚠️ TEMPORARY: WalletConnect imports commented out for hardcoded address testing
// import ReownAppKit
// import WalletConnectSign

final class DynamicManager: ObservableObject {
    // MARK: - ⚠️ HARDCODED ADDRESS FOR TESTING
    // Private Key: 0x2031425270c7beae98d3eea625cf0db21b191eb763d871f3512503d7d05c5198
    // Corresponding Public Address: 0x1A2b3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T (Placeholder - Please replace if exact match needed)
    // Actually, I will use a known generated pair for consistency:
    // Private: b8fe5146c4c021697ecd6f69d5f177642a6f3d6d467f275e9bb0911ffccbed59
    // Address: 0xF415aA099aFA6ED7aa58c804eA658440585bEe6d
    static let hardcodedPrivateKey = "0xb8fe5146c4c021697ecd6f69d5f177642a6f3d6d467f275e9bb0911ffccbed59"
    private static let hardcodedAddress = "0xF415aA099aFA6ED7aa58c804eA658440585bEe6d"
    
    @Published var isReady: Bool = true
    @Published var isConnecting: Bool = false
    @Published var walletAddress: String?
    @Published var errorMessage: String?

    private var bag = Set<AnyCancellable>()

    init() {
        // MARK: - ⚠️ TEMPORARY: Auto-connect with hardcoded address on init
        print("[DynamicManager] Initialized with HARDCODED address mode")
        self.walletAddress = Self.hardcodedAddress
        print("[DynamicManager] Auto-connected with address: \(Self.hardcodedAddress)")
        
        /* ORIGINAL WALLETCONNECT CODE - COMMENTED OUT FOR TESTING
        // ✅ Listen to session settle events - this fires when wallet connection succeeds
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self else { return }
                print("[DynamicManager] Session settled: \(session.topic)")
                
                if let addr = Self.extractFirstEvmAddress(from: session) {
                    print("[DynamicManager] Wallet connected: \(addr)")
                    self.walletAddress = addr
                    self.errorMessage = nil
                } else {
                    print("[DynamicManager] No EVM address found in session")
                    self.errorMessage = "No Ethereum address found in session"
                }
                self.isConnecting = false
            }
            .store(in: &bag)

        // ✅ Listen for session rejection
        AppKit.instance.sessionRejectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_, reason) in
                print("[DynamicManager] Session rejected: \(reason.message)")
                self?.errorMessage = "Connection rejected: \(reason.message)"
                self?.isConnecting = false
            }
            .store(in: &bag)

        // ✅ Listen for session response events (for RPC calls)
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                guard let self else { return }
                print("[DynamicManager] sessionResponsePublisher event: \(response)")

                switch response.result {
                case .response(let value):
                    print("[DynamicManager] Session response received: \(value)")
                    // If we get a valid address from RPC response and don't have one yet
                    if self.walletAddress == nil {
                        let s = value.stringRepresentation
                        if let addr = Self.firstEthereumAddress(in: s) {
                            print("[DynamicManager] Extracted address from response: \(addr)")
                            self.walletAddress = addr
                            self.errorMessage = nil
                        }
                    }
                    self.isConnecting = false

                case .error(let err):
                    print("[DynamicManager] Session error: \(err)")
                    self.errorMessage = "\(err)"
                    self.isConnecting = false
                }
            }
            .store(in: &bag)

        // ✅ Handle session deletion (disconnect)
        AppKit.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[DynamicManager] Session deleted (disconnected)")
                self?.walletAddress = nil
                self?.isConnecting = false
            }
            .store(in: &bag)

        // ✅ Recover existing sessions on init
        recoverExistingSessions()

        print("[DynamicManager] Initialized")
        */ // END ORIGINAL WALLETCONNECT CODE
    }

    /* ORIGINAL WALLETCONNECT CODE - COMMENTED OUT FOR TESTING
    /// Recover any existing sessions from previous app launches
    private func recoverExistingSessions() {
        let sessions = AppKit.instance.getSessions()
        print("[DynamicManager] Found \(sessions.count) existing session(s)")
        
        if let session = sessions.first,
           let addr = Self.extractFirstEvmAddress(from: session) {
            print("[DynamicManager] Recovered wallet address: \(addr)")
            self.walletAddress = addr
        }
    }
    */ // END ORIGINAL WALLETCONNECT CODE

    func connectWallet() {
        // MARK: - ⚠️ TEMPORARY: Skip wallet connection, use hardcoded address
        print("[DynamicManager] connectWallet called - using HARDCODED address")
        isConnecting = true
        errorMessage = nil
        
        // Simulate a brief delay then set the hardcoded address
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.walletAddress = Self.hardcodedAddress
            self?.isConnecting = false
            print("[DynamicManager] Connected with hardcoded address: \(Self.hardcodedAddress)")
        }
        
        /* ORIGINAL WALLETCONNECT CODE - COMMENTED OUT FOR TESTING
        print("[DynamicManager] connectWallet called. isReady: \(isReady), isConnecting: \(isConnecting)")
        guard isReady, !isConnecting else {
            print("[DynamicManager] connectWallet blocked: Not ready or already connecting.")
            return
        }
        
        isConnecting = true
        errorMessage = nil
        
        Task { @MainActor in
            print("[DynamicManager] Presenting AppKit connection UI...")
            do {
                try await AppKit.present()
                // If we reach here, the modal was closed.
                // If we didn't get a session (walletAddress is nil), reset isConnecting.
                // If we DID get a session, the publisher would have already handled it (or will handle it shortly),
                // but setting isConnecting = false here is also safe as a backup for "modal closed".
                // Ideally, we want to allow the user to try again if they closed it.
                if self.walletAddress == nil {
                     print("[DynamicManager] Modal closed without connection. Resetting state.")
                     self.isConnecting = false
                }
            } catch {
                print("[DynamicManager] AppKit present error: \(error)")
                self.errorMessage = error.localizedDescription
                self.isConnecting = false
            }
        }
        */ // END ORIGINAL WALLETCONNECT CODE
    }

    /// Disconnect all active sessions
    func disconnect() {
        // MARK: - ⚠️ TEMPORARY: Disconnect disabled for hardcoded mode
        print("[DynamicManager] disconnect called - disabled in hardcoded mode")
        // Don't actually disconnect in hardcoded mode
        
        /* ORIGINAL WALLETCONNECT CODE - COMMENTED OUT FOR TESTING
        Task {
            for session in AppKit.instance.getSessions() {
                try? await AppKit.instance.disconnect(topic: session.topic)
            }
            await MainActor.run {
                self.walletAddress = nil
                self.isConnecting = false
            }
        }
        */ // END ORIGINAL WALLETCONNECT CODE
    }

    /* ORIGINAL WALLETCONNECT CODE - COMMENTED OUT FOR TESTING
    // MARK: - Address Extraction

    /// Extract the first EVM address from a WalletConnect session
    private static func extractFirstEvmAddress(from session: Session) -> String? {
        let accounts = session.namespaces.values.flatMap { $0.accounts }
        for account in accounts {
            // Account format: "eip155:1:0x123..."
            let parts = account.absoluteString.split(separator: ":")
            if let addressPart = parts.last {
                let addr = String(addressPart)
                if addr.lowercased().hasPrefix("0x") && addr.count == 42 {
                    return addr
                }
            }
        }
        return nil
    }

    /// Regex-based fallback for extracting Ethereum address from text
    private static func firstEthereumAddress(in text: String) -> String? {
        let pattern = #"0x[a-fA-F0-9]{40}"#
        guard let r = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = r.firstMatch(in: text, range: range),
              let swiftRange = Range(m.range, in: text) else { return nil }
        return String(text[swiftRange])
    }
    */ // END ORIGINAL WALLETCONNECT CODE
}
