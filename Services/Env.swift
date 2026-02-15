//
//  Env.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 02/01/26.
//

import Foundation

enum Env {
    static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var dynamicEnvironmentId: String { plist("DYNAMIC_ENVIRONMENT_ID") }
    static var dynamicBaseURL: String { plist("DYNAMIC_BASE_URL") }
    static var dynamicRelayHost: String { plist("DYNAMIC_RELAY_HOST") }

    static var wcRelayHost: String { plist("WCRelayHost") }
    static var wcProjectId: String { plist("WCProjectId") }
    static var wcRelayURL: String { plist("WCRelayURL") }
}

struct WCEnvValidator {
    struct Result {
        let host: String
        let projectId: String
        let relayURLString: String
        let errors: [String]
    }

    static func validate() -> Result {
        let host = Env.wcRelayHost
        let projectId = Env.wcProjectId
        let relayURLString = Env.wcRelayURL
        var errors: [String] = []

        if host.isEmpty {
            errors.append("WCRelayHost is empty. Ensure Info.plist has WCRelayHost = $(WC_RELAY_HOST) and Secrets.xcconfig sets WC_RELAY_HOST.")
        } else if host != "relay.walletconnect.com" {
            errors.append("WCRelayHost is '\(host)'. Expected 'relay.walletconnect.com' for Reown/WalletConnect Cloud Relay.")
        }

        if projectId.isEmpty || projectId == "wss:" {
            errors.append("WCProjectId is invalid ('\(projectId)'). Ensure WC_PROJECT_ID in Secrets.xcconfig is the plain project id string from the dashboard.")
        }

        if relayURLString.isEmpty || !relayURLString.hasPrefix("wss://") || !relayURLString.contains("projectId=") {
            errors.append("WCRelayURL is invalid ('\(relayURLString)'). In Info.plist set WCRelayURL = wss://$(WC_RELAY_HOST)?projectId=$(WC_PROJECT_ID)&bundleId=$(PRODUCT_BUNDLE_IDENTIFIER).")
        }

        return Result(host: host, projectId: projectId, relayURLString: relayURLString, errors: errors)
    }
}
