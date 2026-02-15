import Foundation

// MARK: - Auth

struct AuthNonceResponse: Decodable {
    let address: String
    let nonce: String
    let message: String
    let ttl: Int
}

struct AuthVerifyRequest: Encodable {
    let address: String
    let signature: String
    let nonce: String?
}

struct AuthVerifyResponse: Decodable {
    let address: String
    let authenticated: Bool
}

// MARK: - Domains

/// Inbox lookup – used when we need XMTP inboxId for a domain
struct DomainLookupResponse: Decodable {
    let inboxId: String?
}

/// Owner lookup – used for validating a typed domain (like the web frontend)
struct DomainOwnerResponse: Decodable {
    let owner: String?
}

// Conversation start response when initiating a chat to a domain
struct StartConversationResponse: Decodable {
    let conversation: ConversationItem
}

struct DomainItem: Decodable, Identifiable {
    var id: String { domain }

    let domain: String
    let tokenized: Bool
    let verificationStatus: String
    let verificationMethod: String?
    let messagingEnabled: Bool
    let pricingTier: String
    let feeWei: String
    let feeEther: String?

    // These are optional because backend may not send them always
    let failureReason: String?
    let verifiedAt: String?
    let lastCheckedAt: String?
}

// MARK: - Conversations (list)

struct ConversationsListResponse: Decodable {
    let owner: String
    let conversations: [ConversationItem]
}

struct ConversationItem: Decodable, Identifiable {
    let id: String
    let domain: String
    let status: String
    let lastActivity: String?
    let createdAt: String?
    let unreadCount: Int
    let preview: String?
}

// MARK: - Messages

struct ConversationMessagesResponse: Decodable {
    let items: [MessageEnvelope]
    let nextCursor: String?
}

struct MessageEnvelope: Decodable, Identifiable {
    let id: String
    let conversationId: String
    let timestamp: Date
    let sender: String
    let msgType: String
    let sizeBytes: Int
    let contentHash: String?
}

// MARK: - Analytics

struct AnalyticsSummaryResponse: Decodable {
    let owner: String?
    let totals: [String: Int]?
}

// MARK: - Sync Conversation

struct SyncConversationResponse: Decodable {
    let id: String
    let status: String?
}

// MARK: - Domain Conversations (XMTP sync)

struct Conversation: Decodable, Identifiable {
    var id: String { conversationId }
    let conversationId: String
    let withDomain: String
    let createdAt: String
}

struct GroupConversation: Decodable, Identifiable {
    var id: String { conversationId }
    let conversationId: String
    let withDomain: String
    let createdAt: String
    let metadata: GroupMetadata

    struct GroupMetadata: Decodable {
        let admin: String?
        let name: String?
    }
}
