# Phase 2 — Swift Models & Protocols Contract

---

## Goal Model

```swift
struct Goal: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var category: GoalCategory
    var title: String
    var description: String?
    var targetValue: Double
    var targetUnit: String
    var currentValue: Double?
    var targetDate: Date?
    var priority: GoalPriority
    var benchmarkTestType: String?
    var testingCadenceWeeks: Int
    var status: GoalStatus
    var metadata: [String: AnyCodable]?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", category, title, description
        case targetValue = "target_value", targetUnit = "target_unit"
        case currentValue = "current_value", targetDate = "target_date"
        case priority, benchmarkTestType = "benchmark_test_type"
        case testingCadenceWeeks = "testing_cadence_weeks", status
        case metadata, createdAt = "created_at", updatedAt = "updated_at"
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case strength, endurance, bodyComposition = "body_composition"
    case biomarker, recovery
}

enum GoalPriority: String, Codable, CaseIterable {
    case primary, secondary, maintenance
}

enum GoalStatus: String, Codable, CaseIterable {
    case active, achieved, paused, abandoned
}
```

---

## Updated HealthCategory Enum

Add these 3 cases to the existing enum in `HealthOS/Models/HealthMetric.swift`:

```swift
case respiratoryRate = "respiratory_rate"
case skinTemperature = "skin_temperature"
case trainingLoad = "training_load"
```

---

## WhoopServiceProtocol

```swift
protocol WhoopServiceProtocol {
    func buildAuthorizationURL() -> URL
    func handleOAuthCallback(code: String) async throws
    func syncData() async throws
    func disconnect() async throws
    var isConnected: Bool { get }
}
```

---

## StravaServiceProtocol

```swift
protocol StravaServiceProtocol {
    func buildAuthorizationURL() -> URL
    func handleOAuthCallback(code: String) async throws
    func syncData() async throws
    func disconnect() async throws
    var isConnected: Bool { get }
}
```

---

## SupabaseService Extensions (needed post-merge)

```swift
// Goals CRUD
func getGoals() async throws -> [Goal]
func getGoals(category: GoalCategory) async throws -> [Goal]
func insertGoal(_ goal: Goal) async throws -> Goal
func updateGoal(_ goal: Goal) async throws -> Goal
func deleteGoal(id: UUID) async throws

// Edge Function invocation
func invokeEdgeFunction(_ name: String, body: [String: Any]?) async throws -> Data
```
