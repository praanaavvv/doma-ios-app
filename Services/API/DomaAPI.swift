import Foundation

final class DomaAPI {
    static let shared = DomaAPI()
    private init() {}

    private struct EmptyResponse: Decodable {}

    // MARK: Auth

    func getNonce(address: String) async throws -> AuthNonceResponse {
        try await APIClient.shared.request(
            "auth/nonce",
            query: ["address": address.lowercased()]
        )
    }

    func verifySignature(address: String, signature: String, nonce: String? = nil) async throws -> AuthVerifyResponse {
        let body = AuthVerifyRequest(
            address: address.lowercased(),
            signature: signature,
            nonce: nonce
        )
        return try await APIClient.shared.request("auth/verify", method: "POST", body: body)
    }

    // MARK: - Domains

    func fetchDomainItems(owner: String) async throws -> [DomainItem] {
        struct DomainsResponseLocal: Decodable { let owner: String; let domains: [DomainItem] }
        let res: DomainsResponseLocal = try await APIClient.shared.request(
            "domains",
            query: ["owner": owner.lowercased()]
        )
        return res.domains
    }

    /// Onboard/register a domain for messaging (configure DNS + policy)
    func onboardDomain(domain: String, owner: String, messagingEnabled: Bool = true, consentMode: String = "auto_accept", feeMode: String = "none") async throws {
        struct Policy: Encodable { let consentMode: String; let feeMode: String }
        struct Body: Encodable { let domain: String; let owner: String; let messagingEnabled: Bool; let policy: Policy }
        let body = Body(domain: domain.lowercased(), owner: owner.lowercased(), messagingEnabled: messagingEnabled, policy: .init(consentMode: consentMode, feeMode: feeMode))
        let _: EmptyResponse = try await APIClient.shared.request(
            "domains/messaging/onboard",
            method: "POST",
            body: body
        )
    }

    /// ✅ Convenience used by DomainsView (returns just the domain strings)
    func fetchDomains(owner: String) async throws -> [String] {
        struct DomainLite: Decodable { let domain: String }
        struct DomainsLiteResponse: Decodable { let owner: String; let domains: [DomainLite] }
        let res: DomainsLiteResponse = try await APIClient.shared.request(
            "domains",
            query: ["owner": owner.lowercased()]
        )
        return res.domains.map { $0.domain }
    }

    /// Resolve the wallet that owns a domain – like getOwnerByDomain in the web frontend
    func getOwnerByDomain(domain: String) async throws -> DomainOwnerResponse {
        try await APIClient.shared.request(
            "domains/owner",
            query: ["domain": domain.lowercased()]
        )
    }

    /// Lookup XMTP inboxId for a domain (backend returns { inboxId: String? })
    func lookupDomain(domain: String) async throws -> DomainLookupResponse {
        try await APIClient.shared.request(
            "domains/lookup",
            query: ["domain": domain.lowercased()]
        )
    }

    // MARK: - Conversations

    func listConversations(owner: String, domain: String? = nil) async throws -> ConversationsListResponse {
        try await APIClient.shared.request(
            "conversations",
            query: [
                "owner": owner.lowercased(),
                "domain": domain?.lowercased()
            ]
        )
    }

    /// Start (or fetch) a conversation from a wallet and optional sender domain to a recipient domain
    func startConversation(fromWallet: String, fromDomain: String? = nil, toDomain: String) async throws -> StartConversationResponse {
        struct Body: Encodable {
            let fromWallet: String
            let fromDomain: String?
            let toDomain: String
        }

        let body = Body(
            fromWallet: fromWallet.lowercased(),
            fromDomain: fromDomain?.lowercased(),
            toDomain: toDomain.lowercased()
        )

        return try await APIClient.shared.request(
            "conversations/start",
            method: "POST",
            body: body
        )
    }

    /// Sync a conversation with backend (used after creating/identifying an XMTP conversation)
    func syncConversation(id: String, senderDomain: String, recipientDomain: String) async throws -> SyncConversationResponse {
        struct Body: Encodable { let id: String; let senderDomain: String; let recipientDomain: String }
        return try await APIClient.shared.request(
            "domains/conversations",
            method: "POST",
            body: Body(id: id, senderDomain: senderDomain, recipientDomain: recipientDomain)
        )
    }

    /// Fetch conversations for a specific domain (sidebar list)
    func getConversations(forDomain domain: String) async throws -> [Conversation] {
        struct ConversationsResponse: Decodable { let domain: String; let conversations: [Conversation] }
        let res: ConversationsResponse = try await APIClient.shared.request(
            "domains/\(domain)/conversations"
        )
        return res.conversations
    }

    /// Upsert a domain group conversation (optional helper)
    func upsertDomainGroupConversation(domain: String, conversationId: String, groupName: String? = nil) async throws {
        struct Body: Encodable { let domain: String; let conversationId: String; let groupName: String? }
        let _: EmptyResponse = try await APIClient.shared.request(
            "domains/group-conversations",
            method: "POST",
            body: Body(domain: domain, conversationId: conversationId, groupName: groupName)
        )
    }

    /// Fetch group conversations for a domain (optional helper)
    func getGroupConversations(domain: String) async throws -> [GroupConversation] {
        try await APIClient.shared.request(
            "domains/group-conversations",
            query: ["domain": domain]
        )
    }

    /// Fetch group conversation members (optional helper)
    func getGroupConversationMembers(conversationId: String) async throws -> [String] {
        struct MemberResponse: Decodable {
            let members: String
        }
        let response: [MemberResponse] = try await APIClient.shared.request(
            "domains/group-conversations/members",
            query: ["conversationId": conversationId]
        )
        return response.map { $0.members }
    }

    /// Send a text message in a conversation
    func sendMessage(conversationId: String, text: String) async throws -> MessageEnvelope {
        struct Body: Encodable { let text: String }
        let body = Body(text: text)
        return try await APIClient.shared.request(
            "conversations/\(conversationId)/messages",
            method: "POST",
            body: body
        )
    }

    func getMessages(conversationId: String, limit: Int = 50, cursor: String? = nil) async throws -> ConversationMessagesResponse {
        try await APIClient.shared.request(
            "conversations/\(conversationId)/messages",
            query: [
                "limit": "\(min(limit, 200))",
                "cursor": cursor
            ]
        )
    }

    // MARK: - Analytics

    func analyticsSummary(owner: String) async throws -> AnalyticsSummaryResponse {
        try await APIClient.shared.request(
            "conversations/analytics/summary",
            query: ["owner": owner.lowercased()]
        )
    }
}
