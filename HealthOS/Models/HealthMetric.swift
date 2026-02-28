import Foundation

/// Normalized health data from all sources.
/// Maps 1:1 to the `health_metrics` database table.
/// All service integrations (HealthKit, Whoop, Strava) produce this type.
struct HealthMetric: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let source: HealthSource
    let category: HealthCategory
    let metricName: String
    let numericValue: Double?
    let textValue: String?
    let unit: String?
    let recordedAt: Date
    /// Date-only component derived from recordedAt; used for efficient date-range queries.
    let recordedDate: Date
    let metadata: [String: AnyCodable]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case source
        case category
        case metricName = "metric_name"
        case numericValue = "numeric_value"
        case textValue = "text_value"
        case unit
        case recordedAt = "recorded_at"
        case recordedDate = "recorded_date"
        case metadata
        case createdAt = "created_at"
    }
}

/// Which integration produced this metric.
enum HealthSource: String, Codable {
    case appleHealthKit = "apple_healthkit"
    case appleCalendar = "apple_calendar"
    case whoop
    case strava
    case manual
}

/// Logical grouping for health metrics — mirrors the DB CHECK constraint.
enum HealthCategory: String, Codable, CaseIterable {
    case sleep
    case workout
    case heartRate = "heart_rate"
    case hrv
    case steps
    case weight
    case bodyFat = "body_fat"
    case activeEnergy = "active_energy"
    case strain
    case recovery
    case calendarEvent = "calendar_event"
    case respiratoryRate = "respiratory_rate"
    case skinTemperature = "skin_temperature"
    case trainingLoad = "training_load"
}
