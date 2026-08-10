import Foundation

/// Types shared by more than one interface. Everything else lives under
/// Care/, Hub/ or Family/ and is prefixed accordingly, because the three
/// interfaces deliberately do NOT share a design system — the Hub's type is
/// sized for an 88-year-old with cataracts and would look absurd on a
/// caregiver's alert list.

/// One row of `public.facilities`, via the `list_facilities()` RPC. Readable
/// before sign-in, which is why it carries nothing but a name.
struct MeridianFacility: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    /// False for a facility nobody has an account at. The picker greys those
    /// out — otherwise someone picks one, cannot possibly sign in, and reads
    /// the failure as a broken app rather than an empty building.
    let hasAccounts: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case hasAccounts = "has_accounts"
    }
}

enum MessageSenderRole: String, Codable {
    case resident, family
}

/// public.messages — one shared thread per resident. Both the Hub and the
/// Family interface read and write it, so it lives here rather than in
/// either one.
struct Message: Codable, Identifiable, Equatable {
    let id: String
    let residentId: String
    let senderRole: MessageSenderRole
    let senderUserId: String
    let senderName: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case residentId = "resident_id"
        case senderRole = "sender_role"
        case senderUserId = "sender_user_id"
        case senderName = "sender_name"
        case body
        case createdAt = "created_at"
    }
}
