import Foundation

/// Represents a user health or fitness goal.
/// Maps 1:1 to the `goals` database table.
struct Goal: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var title: String
    var description: String?
    var category: GoalCategory
    var targetValue: Decimal
    var targetUnit: String
    var currentValue: Decimal?
    var targetDate: Date?
    var priority: GoalPriority
    var benchmarkTestType: String?
    var testingCadenceWeeks: Int
    var status: GoalStatus
    var metadata: [String: AnyCodable]?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case category
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case currentValue = "current_value"
        case targetDate = "target_date"
        case priority
        case benchmarkTestType = "benchmark_test_type"
        case testingCadenceWeeks = "testing_cadence_weeks"
        case status
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Goal category aligned with the PRD.
enum GoalCategory: String, Codable, CaseIterable {
    case strength
    case endurance
    case bodyComposition = "body_composition"
    case biomarker
    case recovery

    var displayName: String {
        switch self {
        case .strength: "Strength"
        case .endurance: "Endurance"
        case .bodyComposition: "Body Composition"
        case .biomarker: "Biomarker"
        case .recovery: "Recovery"
        }
    }

    var icon: String {
        switch self {
        case .strength: "figure.strengthtraining"
        case .endurance: "figure.run"
        case .bodyComposition: "figure.stairs"
        case .biomarker: "heart.fill"
        case .recovery: "moon.stars.fill"
        }
    }
}

/// Goal priority level.
enum GoalPriority: String, Codable, CaseIterable {
    case primary
    case secondary
    case maintenance

    var displayName: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .maintenance: "Maintenance"
        }
    }

    var color: String {
        switch self {
        case .primary: "red"
        case .secondary: "orange"
        case .maintenance: "blue"
        }
    }
}

/// Goal status.
enum GoalStatus: String, Codable, CaseIterable {
    case active
    case achieved
    case paused
    case abandoned

    var displayName: String {
        switch self {
        case .active: "Active"
        case .achieved: "Achieved"
        case .paused: "Paused"
        case .abandoned: "Abandoned"
        }
    }
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
