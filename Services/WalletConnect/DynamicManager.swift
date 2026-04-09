import Foundation
import Combine
import ReownAppKit
import WalletConnectSign

final class DynamicManager: ObservableObject {
    @Published var isReady: Bool = true
    @Published var isConnecting: Bool = false
    @Published var walletAddress: String?
    @Published var errorMessage: String?

    private var bag = Set<AnyCancellable>()

    init() {
        // --- WalletConnect listeners ---
        
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

        // ✅ Recover existing sessions on init (for production WalletConnect flow)
        recoverExistingSessions()
        

        print("[DynamicManager] Initialized")
    }

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

    func connectWallet() {
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
    }

    func disconnect() async {
        print("[DynamicManager] Disconnect requested...")
        
        // Iterate through known AppKit sessions and forcefully disconnect each
        for session in AppKit.instance.getSessions() {
            print("[DynamicManager] Disconnecting session topic: \(session.topic)")
            do {
                try await AppKit.instance.disconnect(topic: session.topic)
            } catch {
                print("[DynamicManager] Failed to disconnect topic \(session.topic): \(error)")
            }
        }
        
        await MainActor.run {
            self.walletAddress = nil
            self.isConnecting = false
            self.errorMessage = nil
            print("[DynamicManager] Local state cleared.")
        }
    }

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
}
