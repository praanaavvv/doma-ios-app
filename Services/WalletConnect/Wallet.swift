import Foundation

struct Wallet: Identifiable, Hashable {
    let id = UUID()
    let name: String
    /// Use "{uri}" placeholder. We'll replace it with URL-encoded wc:... URI.
    let deeplinkTemplate: String

    static let metaMask = Wallet(name: "MetaMask", deeplinkTemplate: "metamask://wc?uri={uri}")
    static let rainbow  = Wallet(name: "Rainbow", deeplinkTemplate: "rainbow://wc?uri={uri}")
    static let trust    = Wallet(name: "Trust Wallet", deeplinkTemplate: "trust://wc?uri={uri}")

    static let all: [Wallet] = [.metaMask, .rainbow, .trust]
}
