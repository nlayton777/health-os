import Foundation

/// Tracks which data sources a user has connected.
/// Maps 1:1 to the `connected_integrations` database table.
struct ConnectedIntegration: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let provider: IntegrationProvider
    var isActive: Bool
    var lastSyncedAt: Date?
    var providerUserId: String?
    var metadata: [String: AnyCodable]?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case provider
        case isActive = "is_active"
        case lastSyncedAt = "last_synced_at"
        case providerUserId = "provider_user_id"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Supported external data sources.
enum IntegrationProvider: String, Codable, CaseIterable {
    case appleHealthKit = "apple_healthkit"
    case appleCalendar = "apple_calendar"
    case whoop = "whoop"
    case strava = "strava"

    var displayName: String {
        switch self {
        case .appleHealthKit: return "Apple Health"
        case .appleCalendar: return "Apple Calendar"
        case .whoop: return "Whoop"
        case .strava: return "Strava"
        }
    }
}

/// Auth state published by SupabaseService.
enum AuthState: Equatable {
    case signedIn(user: AuthUser)
    case signedOut

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.signedOut, .signedOut): return true
        case (.signedIn(let a), .signedIn(let b)): return a.id == b.id
        default: return false
        }
    }
}

/// Minimal user representation from Supabase Auth.
struct AuthUser: Equatable {
    let id: UUID
    let email: String?
}

// MARK: - AnyCodable

/// Type-erased Codable wrapper for heterogeneous JSON values.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:    try container.encode(bool)
        case let int as Int:      try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
