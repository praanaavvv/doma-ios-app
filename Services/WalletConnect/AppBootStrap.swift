import Combine
//import Sentry
import SwiftUI
import UIKit
import WalletConnectSign
import ReownAppKit

//#if DEBUG
//import Atlantis
//#endif

class SocketConnectionManager: ObservableObject {
    @Published var socketConnected: Bool = false
}

class AppViewModel: ObservableObject {
    var disposeBag = Set<AnyCancellable>()
    var socketConnectionManager = SocketConnectionManager()
    @Published var alertMessage: String = ""

    init() {

        let projectId = Env.wcProjectId
        
        let validation = WCEnvValidator.validate()
        print("[Env] WC Relay Host: \(validation.host)")
        print("[Env] WC Relay URL: \(validation.relayURLString)")
        if !validation.errors.isEmpty {
            print("⚠️ [Env Validation] Issues detected:")
            validation.errors.forEach { print("  - \($0)") }
            #if DEBUG
            assertionFailure("WalletConnect environment misconfigured. See console for details.")
            #endif
        }
        
        let resolvedRelayHost = Env.wcRelayHost
        let resolvedRelayURL = Env.wcRelayURL
        print("[Env] WC Relay Host: \(resolvedRelayHost)")
        print("[Env] WC Relay URL: \(resolvedRelayURL)")

        // Initialize metadata
        let metadata = AppMetadata(
            name: "DomaSecure",
            description: "DomaSecure iOS app",
            url: "https://domasecure.app",
            icons: ["https://avatars.githubusercontent.com/u/37784886"], // replace with your icon URL if you have one
            redirect: try! .init(
                native: "domasecure://",
                universal: nil,          // add later if you set up Universal Links
                linkMode: false
            )
        )


        // Pseudocode if your SDK allows passing host
        print("[AppBootStrap] Configuring Networking with ProjectID: \(Env.wcProjectId)")
        Networking.configure(
            relayHost: Env.wcRelayHost,
            groupIdentifier: "group.com.d3globalinc.domasecureios",
            projectId: Env.wcProjectId,
            socketFactory: DefaultSocketFactory(),
            socketConnectionType: .automatic
        )
        print("[AppBootStrap] Networking configured.")

        // Create Session Params
        let chains: [Blockchain] = [Blockchain("eip155:1")!] // Ethereum Mainnet
        let methods: Set<String> = ["personal_sign", "eth_sendTransaction", "eth_signTypedData"]
        let events: Set<String> = ["chainChanged", "accountsChanged"]
        
        // Recommended: Use optionalNamespaces for broad compatibility.
        // Android wallets often reject proposals if they don't support strictly everything in 'required'.
        let namespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: chains,
                methods: methods,
                events: events
            )
        ]
        
        let sessionParams = SessionParams(
            requiredNamespaces: [:], // Empty required allows maximum compatibility
            optionalNamespaces: namespaces, // Put everything here
            sessionProperties: nil
        )

        AppKit.configure(
            projectId: projectId,
            metadata: metadata,
            crypto: DefaultCryptoProvider(),
            sessionParams: sessionParams,
            authRequestParams: nil, // use .stub() for testing SIWE
            customWallets: [
                .init(
                    id: "swift-sample",
                    name: "Swift Sample Wallet",
                    homepage: "https://walletconnect.com/",
                    imageUrl: "https://avatars.githubusercontent.com/u/37784886?s=200&v=4",
                    order: 1,
                    mobileLink: "walletapp://",
                    linkMode: "https://lab.web3modal.com/wallet"
                )
            ]
        ) { error in
            // Handle error
            print(error)
        }

        setup()
    }

    private func setup() {
        AppKit.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("Socket connection status: \(status)")
                self?.socketConnectionManager.socketConnected = (status == .connected)
            }
            .store(in: &disposeBag)

        AppKit.instance.logger.setLogging(level: .debug)
        Sign.instance.setLogging(level: .debug)
        Networking.instance.setLogging(level: .debug)
        Relay.instance.setLogging(level: .debug)

//        AppKit.instance.authResponsePublisher
//            .sink { [weak self] (id: RPCID, result: Result<(Session?, [Cacao]), AuthError>) in
//                switch result {
//                case .success((_, _)):
//                    AlertPresenter.present(message: "User authenticated", type: .success)
//                case .failure(let error):
//                    AlertPresenter.present(message: "User authentication error: \(error)", type: .error)
//                }
//            }
//            .store(in: &disposeBag)

//        AppKit.instance.SIWEAuthenticationPublisher
//            .sink { [weak self] result in
//                switch result {
//                case .success((let message, let signature)):
//                    AlertPresenter.present(message: "User authenticated", type: .success)
//                case .failure(let error):
//                    AlertPresenter.present(message: "User authentication error: \(error)", type: .error)
//                }
//            }
//            .store(in: &disposeBag)
    }
}

//@main
struct AppKitLabApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel.socketConnectionManager)
                .onOpenURL { url in
                    AppKit.instance.handleDeeplink(url)
                }
                .alert(
                    "Response",
                    isPresented: Binding(
                        get: { !viewModel.alertMessage.isEmpty },
                        set: { _ in viewModel.alertMessage = "" }
                    )
                ) {
                    Button("Dismiss", role: .cancel) {}
                } message: {
                    Text(viewModel.alertMessage)
                }
                .onReceive(AppKit.instance.sessionResponsePublisher) { response in
                    switch response.result {
                    case let .response(value):
                        viewModel.alertMessage = "Session response: \(value.stringRepresentation)"
                    case let .error(error):
                        viewModel.alertMessage = "Session error: \(error)"
                    }
                }
        }
    }
}

extension AuthRequestParams {
    static func stub(
        domain: String = "lab.web3modal.com",
        chains: [String] = ["eip155:1", "eip155:137"],
        nonce: String = "32891756",
        uri: String = "https://lab.web3modal.com",
        nbf: String? = nil,
        exp: String? = nil,
        statement: String? = "I accept the ServiceOrg Terms of Service: https://lab.web3modal.com",
        requestId: String? = nil,
        resources: [String]? = nil,
        methods: [String]? = ["personal_sign", "eth_sendTransaction"]
    ) -> AuthRequestParams {
        return try! AuthRequestParams(
            domain: domain,
            chains: chains,
            nonce: nonce,
            uri: uri,
            nbf: nbf,
            exp: exp,
            statement: statement,
            requestId: requestId,
            resources: resources,
            methods: methods
        )
    }
}

