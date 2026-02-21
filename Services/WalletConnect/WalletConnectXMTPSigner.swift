import Foundation
import WalletConnectSign
import ReownAppKit
import Combine
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
        print("[WCSigner] Requesting personal_sign from wallet...")

        // Convert message to hex for personal_sign
        let messageData = Data(message.utf8)
        let hexMessage = "0x" + messageData.map { String(format: "%02x", $0) }.joined()

        // Build the RPC request
        let chainId = "eip155:1"
        let blockchain = Blockchain(chainId)!

        let request = try Request(
            topic: session.topic,
            method: "personal_sign",
            params: AnyCodable([hexMessage, walletAddress]),
            chainId: blockchain
        )

        // Use Sign SDK to send request and wait for response via publisher
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?

            cancellable = AppKit.instance.sessionResponsePublisher
                .filter { $0.topic == self.session.topic }
                .first()
                .receive(on: DispatchQueue.main)
                .sink { response in
                    cancellable?.cancel()

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

            // Send the request — this will prompt the user in MetaMask
            Task {
                do {
                    try await AppKit.instance.request(params: request)
                    print("[WCSigner] Sign request sent to wallet, waiting for approval...")
                    // Deep-link to the connected wallet so the user can see & approve the request
                    await MainActor.run {
                        AppKit.instance.launchCurrentWallet()
                    }
                } catch {
                    cancellable?.cancel()
                    continuation.resume(throwing: error)
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
