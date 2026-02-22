import Foundation
import SwiftUI
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthed: Bool = false
    
    // WebSocket client for real-time events
    let webSocket = DomaWebSocket()

    // ✅ the Domains screen is clearly reading this
    @Published var walletAddress: String? = nil

    // ✅ Domains screen should render from this
    @Published var domains: [String] = []
    @Published var activeDomain: String? = nil {
        didSet {
            if let domain = activeDomain, !domain.isEmpty {
                webSocket.connect(domain: domain)
            } else {
                webSocket.disconnect()
            }
        }
    }

    @Published var isLoadingDomains: Bool = false
    @Published var domainsError: String? = nil

    func refreshDomains() async {
        guard let addr = walletAddress, !addr.isEmpty else {
            domains = []
            domainsError = "Wallet address not set."
            return
        }

        isLoadingDomains = true
        domainsError = nil
        defer { isLoadingDomains = false }

        do {
            let result = try await DomaAPI.shared.fetchWalletData(wallet: addr)
            // ✅ update exactly what the UI shows
            domains = result.domains ?? []
        } catch {
            domains = []
            domainsError = error.localizedDescription
        }
    }
}

