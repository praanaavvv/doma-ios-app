import Foundation
import Web3
import BigInt
import CryptoSwift
import WalletConnectSigner

struct DefaultCryptoProvider: CryptoProvider {

    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let msgBytes: [UInt8] = Array(message)
        let rBytes: [UInt8] = Array(signature.r)
        let sBytes: [UInt8] = Array(signature.s)

        let publicKey = try EthereumPublicKey(
            message: msgBytes,
            v: EthereumQuantity(quantity: BigUInt(signature.v)),
            r: EthereumQuantity(rBytes),
            s: EthereumQuantity(sBytes)
        )

        return Data(publicKey.rawPublicKey)
    }

    func keccak256(_ data: Foundation.Data) -> Foundation.Data {
        let bytes: [UInt8] = Array(data) // ✅ Data -> [UInt8] safely
        let hashBytes = SHA3(variant: .keccak256).calculate(for: bytes)
        return Foundation.Data(hashBytes)
    }
}
