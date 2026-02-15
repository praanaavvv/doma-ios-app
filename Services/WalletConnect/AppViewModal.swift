////
////  AppViewModal.swift
////  DomaSecure
////
////  Created by Pranav Agarwal on 02/01/26.
////
//
//import Combine
//import Foundation
//import SwiftUI
//import UIKit
//
//import WalletConnectSign
//import WalletConnectRelay
//import WalletConnectNetworking
//import ReownAppKit
//
//final class SocketConnectionManager: ObservableObject {
//    @Published var socketConnected: Bool = false
//}
//
//@MainActor
//final class AppViewModel: ObservableObject {
//    var disposeBag = Set<AnyCancellable>()
//    let socketConnectionManager = SocketConnectionManager()
//    @Published var alertMessage: String = ""
//
//    init() {
//        let projectId = "31c2d66b2b7784cbdff2bbd9ab636d89"
//
//        let metadata = AppMetadata(
//            name: "Doma Secure",
//            description: "Wallet connection",
//            url: "domasecure.app",
//            icons: ["https://avatars.githubusercontent.com/u/37784886"],
//            redirect: try! .init(
//                native: "domasecure://",
//                universal: nil,
//                linkMode: true
//            )
//        )
//
//        Networking.configure(
//            groupIdentifier: "group.com.domasecure.app",
//            projectId: projectId,
//            socketFactory: DefaultSocketFactory()
//        )
//
//        AppKit.configure(
//            projectId: projectId,
//            metadata: metadata,
//            crypto: DefaultCryptoProvider(),
//            authRequestParams: nil,     // ✅ wallet-only
//            customWallets: []           // keep empty unless you need a sample wallet
//        ) { error in
//            print("❌ AppKit.configure error:", error)
//        }
//
//        setup()
//    }
//
//    private func setup() {
//        AppKit.instance.socketConnectionStatusPublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] status in
//                self?.socketConnectionManager.socketConnected = (status == .connected)
//                print("Socket status:", status)
//            }
//            .store(in: &disposeBag)
//
//        // Debug logs (same as AppKitLab)
//        AppKit.instance.logger.setLogging(level: .debug)
//        Sign.instance.setLogging(level: .debug)
//        Networking.instance.setLogging(level: .debug)
//        Relay.instance.setLogging(level: .debug)
//
//        // Optional: show request responses in-app (AppKitLab style)
//        AppKit.instance.sessionResponsePublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] response in
//                switch response.result {
//                case let .response(value):
//                    self?.alertMessage = "Session response: \(value.stringRepresentation)"
//                case let .error(error):
//                    self?.alertMessage = "Session error: \(error)"
//                }
//            }
//            .store(in: &disposeBag)
//    }
//}
