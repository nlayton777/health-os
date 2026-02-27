import Foundation

/// Maps 1:1 to the `profiles` database table.
struct Profile: Identifiable, Codable {
    let id: UUID
    var displayName: String?
    var dateOfBirth: Date?
    var heightCm: Double?
    var weightKg: Double?
    var sex: Sex?
    var timezone: String
    var dailyTimeBudgetMin: Int
    var onboardingCompleted: Bool
    let createdAt: Date
    var updatedAt: Date

    enum Sex: String, Codable, CaseIterable {
        case male
        case female
        case other
        case preferNotToSay = "prefer_not_to_say"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case dateOfBirth = "date_of_birth"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case sex
        case timezone
        case dailyTimeBudgetMin = "daily_time_budget_min"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
