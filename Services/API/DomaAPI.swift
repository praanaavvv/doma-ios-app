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
        try await APIClient.shared.requestVoid(
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

    // MARK: - Profile & Wallet Sync

    struct WalletDataResponse: Decodable {
        let status: String
        let wallet: String?
        let name: String?
        let domains: [String]?
    }

    struct SetupProfileResponse: Decodable {
        let status: String
        let wallet: String
        let name: String
        let domains: [String]
    }

    struct SyncWalletResponse: Decodable {
        let status: String
    }
    
    func fetchWalletData(wallet: String) async throws -> WalletDataResponse {
        let response: WalletDataResponse = try await APIClient.shared.request(
            "domains/wallet-data",
            query: ["wallet": wallet]
        )
        print("DEBUG WalletDataResponse for \(wallet): \(response)")
        return response
    }

    /// Create/Update profile name and sync domains
    func setupProfile(wallet: String, name: String) async throws -> SetupProfileResponse {
        struct Body: Encodable {
            let wallet: String
            let name: String
        }
        return try await APIClient.shared.request(
            "domains/setup-profile",
            method: "POST",
            body: Body(wallet: wallet, name: name)
        )
    }

    /// Edit the profile name for a wallet
    func editProfile(wallet: String, name: String) async throws -> SetupProfileResponse {
        struct Body: Encodable {
            let wallet: String
            let name: String
        }
        return try await APIClient.shared.request(
            "domains/edit-profile",
            method: "PATCH",
            body: Body(wallet: wallet, name: name)
        )
    }

    /// Sync domains for a wallet (e.g. if purchase happens outside app)
    func syncWallet(wallet: String) async throws -> SyncWalletResponse {
        struct Body: Encodable { let wallet: String }
        return try await APIClient.shared.request(
            "domains/sync-wallet",
            method: "POST",
            body: Body(wallet: wallet)
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
        print("DEBUG: Conversations for \(domain): \(res.conversations)")
        return res.conversations
    }

    /// Upsert a domain group conversation — called once per member domain
    @discardableResult
    func upsertDomainGroupConversation(conversationId: String, memberDomain: String, actorDomain: String, groupName: String? = nil) async throws -> GroupMember {
        struct Body: Encodable { let conversationId: String; let domain: String; let actorDomain: String; let groupName: String? }
        return try await APIClient.shared.request(
            "domains/group-conversations",
            method: "POST",
            body: Body(conversationId: conversationId, domain: memberDomain, actorDomain: actorDomain, groupName: groupName)
        )
    }

    /// Fetch group conversations for a domain (optional helper)
    func getGroupConversations(domain: String) async throws -> [GroupConversation] {
        try await APIClient.shared.request(
            "domains/group-conversations",
            query: ["domain": domain]
        )
    }

    /// Fetch group conversation members — returns [{domain, wallet, name, role}]
    func getGroupConversationMembers(conversationId: String) async throws -> [GroupMember] {
        try await APIClient.shared.request(
            "domains/group-conversations/members",
            query: ["conversationId": conversationId]
        )
    }

    /// Add a member to a group conversation
    func addGroupMember(conversationId: String, requesterDomain: String, memberDomain: String) async throws {
        struct Body: Encodable { let requesterDomain: String; let memberDomain: String }
        try await APIClient.shared.requestVoid(
            "domains/group-conversations/\(conversationId)/members",
            method: "POST",
            body: Body(requesterDomain: requesterDomain, memberDomain: memberDomain)
        )
    }

    /// Remove a member from a group conversation
    func removeGroupMember(conversationId: String, requesterDomain: String, memberDomain: String) async throws {
        try await APIClient.shared.requestVoid(
            "domains/group-conversations/\(conversationId)/members/\(memberDomain)",
            method: "DELETE",
            query: ["requesterDomain": requesterDomain]
        )
    }

    /// Get group admins
    func getGroupAdmins(conversationId: String) async throws -> GroupAdminsResponse {
        try await APIClient.shared.request(
            "domains/group-conversations/admins",
            query: ["conversationId": conversationId]
        )
    }

    /// Promote member to admin
    func promoteGroupAdmin(conversationId: String, actorDomain: String, targetAdminDomain: String) async throws {
        struct Body: Encodable { let domain: String; let adminDomain: String }
        try await APIClient.shared.requestVoid(
            "domains/group-conversations/\(conversationId)/admins",
            method: "POST",
            body: Body(domain: actorDomain, adminDomain: targetAdminDomain)
        )
    }

    /// Demote delegated admin
    func demoteGroupAdmin(conversationId: String, ownerDomain: String, adminDomain: String) async throws {
        try await APIClient.shared.requestVoid(
            "domains/group-conversations/\(conversationId)/admins/\(adminDomain)",
            method: "DELETE",
            query: ["domain": ownerDomain]
        )
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
    
    struct DomainAnalyticsResponse: Decodable {
        let domain: String
        let totalMessages: Int
        let totalMessagesLastWeek: Int
        let percentChange: Double
        let engagementRate: Double
        let heatmap: [AnalyticsHeatmapDay]
    }

    struct AnalyticsHeatmapDay: Decodable, Identifiable {
        var id: Int { day }
        let day: Int
        let hours: [Int]
    }

    func getDomainAnalytics(domain: String) async throws -> DomainAnalyticsResponse {
        try await APIClient.shared.request(
            "domains/analytics",
            query: ["domain": domain.lowercased()]
        )
    }

    func analyticsSummary(owner: String) async throws -> AnalyticsSummaryResponse {
        try await APIClient.shared.request(
            "conversations/analytics/summary",
            query: ["owner": owner.lowercased()]
        )
    }
}
