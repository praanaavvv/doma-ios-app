import Foundation
import WalletConnectSign
import ReownAppKit
import Combine
import WalletConnectNetworking
#if canImport(XMTPiOS)
import XMTPiOS
#endif

/// A WalletConnect-backed signer that conforms to XMTP's SigningKey protocol.
/// When XMTP needs to sign a message, this delegates to MetaMask (or any connected wallet)
/// via WalletConnect's `personal_sign` RPC method.
#if canImport(XMTPiOS)
class WalletConnectXMTPSigner: SigningKey {
    private let walletAddress: String
    private let session: Session

    var identity: PublicIdentity {
        PublicIdentity(kind: .ethereum, identifier: walletAddress)
    }

    var type: SignerType { .EOA }
    var chainId: Int64? { nil }
    var blockNumber: Int64? { nil }

    init(address: String, session: Session) {
        self.walletAddress = address
        self.session = session
    }

    func sign(_ message: String) async throws -> SignedData {
        print("[WCSigner] Requesting personal_sign (Topic: \(session.topic))")
        print("[WCSigner] Message content: \(message)")

        // Let ReownAppKit format the request properly
        // rather than manually building the RPC call.

        var success = false
        
        // Use Sign SDK to send request and wait for response via publisher
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?

            cancellable = Sign.instance.sessionResponsePublisher
                .filter { $0.topic == self.session.topic }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { response in
                    cancellable?.cancel()
                    success = true // Stop the retry loop

                    switch response.result {
                    case .response(let value):
                        let hexSig = value.stringRepresentation
                            .replacingOccurrences(of: "\"", with: "")
                        print("[WCSigner] ✅ Got signature: \(hexSig.prefix(20))...")
                        let sigData = Data(hexString: hexSig)
                        continuation.resume(returning: SignedData(rawData: sigData))

                    case .error(let error):
                        print("[WCSigner] ❌ Signing rejected: \(error)")
                        continuation.resume(throwing: XmtpServiceError.generic("Wallet rejected signing: \(error)"))
                    }
                }

            // 2. Start a retry loop for the sign request
            Task {
                do {
                    // Wait for the relay WebSocket to be connected (with 5s fallback)
                    await waitForSocketConnection()

                    // Ensure the session is actually valid and active in the Sign SDK
                    let activeSessions = Sign.instance.getSessions()
                    guard let activeSession = activeSessions.first(where: { $0.topic == self.session.topic }) else {
                        print("[WCSigner] ❌ Session topic \(self.session.topic) no longer active.")
                        cancellable?.cancel()
                        continuation.resume(throwing: XmtpServiceError.generic("Session expired. Please reconnect."))
                        return
                    }

                    var attempt = 1
                    let maxAttempts = 2
                    
                    while attempt <= maxAttempts && !success {
                        print("[WCSigner] Sending personal_sign request (Attempt \(attempt))...")
                        
                        // Use direct Sign SDK for the RPC request to avoid AppKit wrapper overhead
                        let method = "personal_sign"
                        let params = AnyCodable([message, self.walletAddress])
                        guard let chainId = Blockchain("eip155:1") else {
                            print("[WCSigner] ❌ Invalid chain ID.")
                            cancellable?.cancel()
                            continuation.resume(throwing: XmtpServiceError.generic("Invalid chain ID."))
                            return
                        }
                        
                        let request = try Request(topic: activeSession.topic, method: method, params: params, chainId: chainId)
                        
                        try await Sign.instance.request(params: request)
                        print("[WCSigner] Request (ID: \(request.id)) sent successfully, opening wallet...")
                        
                        // Deep-link to the connected wallet immediately
                        await MainActor.run {
                            AppKit.instance.launchCurrentWallet()
                        }
                        
                        // Wait up to 8 seconds for a response.
                        let startTime = Date()
                        while Date().timeIntervalSince(startTime) < 8.0 {
                            if success { break }
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        
                        // Final safety check for THIS attempt
                        if !success && attempt < maxAttempts {
                            print("[WCSigner] ⚠️ No response received in 8s for attempt \(attempt). Retrying...")
                            attempt += 1
                        } else if !success {
                            print("[WCSigner] ❌ Final attempt failed. No response from wallet.")
                            break // Exit the attempt loop
                        }
                    }
                    
                    // Final safety fallback: If the loop finished but success was never true (sink never fired)
                    if !success {
                        print("[WCSigner] ❌ Continuation fallback: Request timed out.")
                        cancellable?.cancel()
                        continuation.resume(throwing: XmtpServiceError.generic("Revocation request timed out. Please ensure your wallet is open and connected, then try again."))
                    }
                } catch {
                    cancellable?.cancel()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Wait for the WalletConnect relay socket to be in the `.connected` state.
    /// Includes a 5-second graceful fallback to proceed anyway if the relay is slow.
    private func waitForSocketConnection() async {
        print("[WCSigner] Waiting for relay socket to connect...")
        
        // Ensure connection is at least attempted
        try? await Networking.instance.connect()
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var cancellable: AnyCancellable?
            var isResumed = false
            
            // 1. Set a 5-second fallback timer
            let fallbackTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                if !isResumed {
                    isResumed = true
                    cancellable?.cancel()
                    print("[WCSigner] ⚠️ Relay socket wait TIMEOUT (5s) - Proceeding anyway...")
                    continuation.resume()
                }
            }
            
            // 2. Subscribe to the socket status
            cancellable = AppKit.instance.socketConnectionStatusPublisher
                .filter { $0 == .connected }
                .first()
                .sink { _ in
                    if !isResumed {
                        isResumed = true
                        fallbackTask.cancel()
                        cancellable?.cancel()
                        print("[WCSigner] ✅ Relay socket connected.")
                        continuation.resume()
                    }
                }
        }
    }
}
#endif

// Helper extension for hex string to Data conversion
extension Data {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var data = Data()
        data.reserveCapacity(hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if nextIndex > index {
                let byteString = hex[index..<nextIndex]
                if let byte = UInt8(byteString, radix: 16) {
                    data.append(byte)
                }
                index = nextIndex
            } else {
                break
            }
        }
        self = data
    }
}
