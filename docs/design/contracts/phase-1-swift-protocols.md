# Phase 1 — Swift Service Protocols Contract

These protocols define the interfaces that the iOS workstream must implement. They establish the contract between the service layer and the views/view models.

---

## SupabaseService

Handles all communication with Supabase (auth + database).

```swift
protocol SupabaseServiceProtocol {
    // Auth
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    func signOut() async throws
    func observeAuthStateChanges() -> AsyncStream<AuthState>

    // Profile
    func getProfile() async throws -> Profile
    func updateProfile(_ profile: Profile) async throws -> Profile

    // Connected Integrations
    func getConnectedIntegrations() async throws -> [ConnectedIntegration]
    func upsertIntegration(_ integration: ConnectedIntegration) async throws
    func deleteIntegration(provider: IntegrationProvider) async throws

    // Health Metrics
    func insertHealthMetrics(_ metrics: [HealthMetric]) async throws
    func getHealthMetrics(category: HealthCategory, from: Date, to: Date) async throws -> [HealthMetric]
}
```

### Key Types

```swift
enum AuthState {
    case signedIn(User)
    case signedOut
}

enum IntegrationProvider: String, Codable, CaseIterable {
    case appleHealthKit = "apple_healthkit"
    case appleCalendar = "apple_calendar"
    case whoop = "whoop"
    case strava = "strava"
}

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
}

enum HealthSource: String, Codable {
    case appleHealthKit = "apple_healthkit"
    case appleCalendar = "apple_calendar"
    case whoop
    case strava
    case manual
}
```

---

## HealthKitService

Handles all Apple HealthKit reads. Does NOT write to Supabase directly — returns normalized `HealthMetric` values that the caller syncs to the backend.

```swift
protocol HealthKitServiceProtocol {
    /// Request HealthKit authorization for all required data types
    func requestAuthorization() async throws -> Bool

    /// Check current authorization status
    var isAuthorized: Bool { get }

    /// Fetch sleep data for a date range
    func fetchSleepData(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch workout data for a date range
    func fetchWorkouts(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch heart rate samples for a date range
    func fetchHeartRate(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch HRV samples for a date range
    func fetchHRV(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch step count for a date range
    func fetchSteps(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch weight samples for a date range
    func fetchWeight(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch body fat percentage samples for a date range
    func fetchBodyFat(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch active energy burned for a date range
    func fetchActiveEnergy(from: Date, to: Date) async throws -> [HealthMetric]
}
```

### HealthKit Data Type Mapping

| HealthKit Type | → `category` | → `metric_name` | → `unit` |
|---|---|---|---|
| `HKCategoryTypeIdentifier.sleepAnalysis` | `sleep` | `sleep_duration` | `hours` |
| `HKCategoryTypeIdentifier.sleepAnalysis` (stages) | `sleep` | `sleep_stage` | — (text_value: rem/deep/core/awake) |
| `HKQuantityTypeIdentifier.heartRate` | `heart_rate` | `heart_rate` | `bpm` |
| `HKQuantityTypeIdentifier.restingHeartRate` | `heart_rate` | `resting_heart_rate` | `bpm` |
| `HKQuantityTypeIdentifier.heartRateVariabilitySDNN` | `hrv` | `hrv_sdnn` | `ms` |
| `HKQuantityTypeIdentifier.stepCount` | `steps` | `step_count` | `steps` |
| `HKQuantityTypeIdentifier.bodyMass` | `weight` | `weight` | `kg` |
| `HKQuantityTypeIdentifier.bodyFatPercentage` | `body_fat` | `body_fat_pct` | `percent` |
| `HKQuantityTypeIdentifier.activeEnergyBurned` | `active_energy` | `active_energy` | `kcal` |
| `HKWorkoutType.workoutType()` | `workout` | `workout_summary` | `minutes` (duration) |

---

## CalendarService

Handles Apple EventKit reads. Returns normalized `HealthMetric` values with `category: .calendarEvent`.

```swift
protocol CalendarServiceProtocol {
    /// Request EventKit authorization
    func requestAuthorization() async throws -> Bool

    /// Check current authorization status
    var isAuthorized: Bool { get }

    /// Fetch today's calendar events
    func fetchEvents(for date: Date) async throws -> [CalendarEvent]

    /// Detect free/busy time windows for a given date
    func fetchFreeWindows(for date: Date, wakeTime: Date, sleepTime: Date) async throws -> [TimeWindow]
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarName: String
}

struct TimeWindow: Identifiable {
    let id: String       // generated
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
}
```

---

## HealthMetric (Shared Model)

This is the unified data model that ALL services produce. It maps 1:1 to the `health_metrics` database table.

```swift
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
    let recordedDate: Date       // date-only, derived from recordedAt
    let metadata: [String: AnyCodable]?
    let createdAt: Date?
}
```

---

## Profile (Shared Model)

Maps 1:1 to the `profiles` database table.

```swift
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
        case male, female, other
        case preferNotToSay = "prefer_not_to_say"
    }
}
```

---

## ConnectedIntegration (Shared Model)

Maps 1:1 to the `connected_integrations` database table.

```swift
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
}
```
