import Foundation
import HealthKit

// MARK: - Protocol

protocol HealthKitServiceProtocol {
    /// Request HealthKit authorization for all required data types.
    func requestAuthorization() async throws -> Bool

    /// Current HealthKit authorization status.
    var isAuthorized: Bool { get }

    /// Fetch sleep data for a date range.
    func fetchSleepData(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch workout data for a date range.
    func fetchWorkouts(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch heart rate samples for a date range.
    func fetchHeartRate(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch HRV (SDNN) samples for a date range.
    func fetchHRV(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch step count for a date range.
    func fetchSteps(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch weight samples for a date range.
    func fetchWeight(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch body fat percentage samples for a date range.
    func fetchBodyFat(from: Date, to: Date) async throws -> [HealthMetric]

    /// Fetch active energy burned for a date range.
    func fetchActiveEnergy(from: Date, to: Date) async throws -> [HealthMetric]
}

// MARK: - Implementation

@Observable
final class HealthKitService: HealthKitServiceProtocol {

    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    private let userId: UUID

    private init() {
        // userId is populated from SupabaseService at call time.
        userId = UUID()
    }

    // MARK: - Authorization

    private var readTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .bodyMass,
            .bodyFatPercentage,
            .activeEnergyBurned
        ]
        for id in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
        return true
    }

    // MARK: - Fetch Helpers

    private func currentUserId() throws -> UUID {
        guard let user = SupabaseService.shared.currentUser else {
            throw HealthKitServiceError.noAuthenticatedUser
        }
        return user.id
    }

    private func recordedDate(from date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func executeQuantityQuery(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from: Date,
        to: Date
    ) async throws -> [(Date, Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let results = (samples as? [HKQuantitySample] ?? []).map { sample in
                    (sample.startDate, sample.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    func fetchSleepData(from: Date, to: Date) async throws -> [HealthMetric] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let userId = try currentUserId()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                guard let self else { return }
                if let error { continuation.resume(throwing: error); return }
                let categorySamples = samples as? [HKCategorySample] ?? []

                var metrics: [HealthMetric] = []
                var totalSleepByDay: [Date: TimeInterval] = [:]

                for sample in categorySamples {
                    let day = self.recordedDate(from: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)

                    // Accumulate total sleep duration per day
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                        totalSleepByDay[day, default: 0] += duration
                    }

                    // Emit sleep stage metric
                    let stageText = sleepStageText(for: sample.value)
                    metrics.append(HealthMetric(
                        id: UUID(),
                        userId: userId,
                        source: .appleHealthKit,
                        category: .sleep,
                        metricName: "sleep_stage",
                        numericValue: nil,
                        textValue: stageText,
                        unit: nil,
                        recordedAt: sample.startDate,
                        recordedDate: day,
                        metadata: nil,
                        createdAt: nil
                    ))
                }

                // Emit daily sleep duration summary
                for (day, totalSeconds) in totalSleepByDay {
                    metrics.append(HealthMetric(
                        id: UUID(),
                        userId: userId,
                        source: .appleHealthKit,
                        category: .sleep,
                        metricName: "sleep_duration",
                        numericValue: totalSeconds / 3600,
                        textValue: nil,
                        unit: "hours",
                        recordedAt: day,
                        recordedDate: day,
                        metadata: nil,
                        createdAt: nil
                    ))
                }

                continuation.resume(returning: metrics)
            }
            store.execute(query)
        }
    }

    private func sleepStageText(for value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "rem"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "deep"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "core"
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
        default: return "unspecified"
        }
    }

    // MARK: - Workouts

    func fetchWorkouts(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { [weak self] _, samples, error in
                guard let self else { return }
                if let error { continuation.resume(throwing: error); return }
                let workouts = samples as? [HKWorkout] ?? []
                let metrics = workouts.map { workout -> HealthMetric in
                    let durationMin = workout.duration / 60
                    let day = self.recordedDate(from: workout.startDate)
                    return HealthMetric(
                        id: UUID(),
                        userId: userId,
                        source: .appleHealthKit,
                        category: .workout,
                        metricName: "workout_summary",
                        numericValue: durationMin,
                        textValue: workout.workoutActivityType.name,
                        unit: "minutes",
                        recordedAt: workout.startDate,
                        recordedDate: day,
                        metadata: nil,
                        createdAt: nil
                    )
                }
                continuation.resume(returning: metrics)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart Rate

    func fetchHeartRate(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .heartRate, metricName: "heart_rate",
                numericValue: value, textValue: nil, unit: "bpm",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }

    // MARK: - HRV

    func fetchHRV(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .hrv, metricName: "hrv_sdnn",
                numericValue: value, textValue: nil, unit: "ms",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }

    // MARK: - Steps

    func fetchSteps(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .stepCount,
            unit: .count(),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .steps, metricName: "step_count",
                numericValue: value, textValue: nil, unit: "steps",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }

    // MARK: - Weight

    func fetchWeight(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .bodyMass,
            unit: .gramUnit(with: .kilo),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .weight, metricName: "weight",
                numericValue: value, textValue: nil, unit: "kg",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }

    // MARK: - Body Fat

    func fetchBodyFat(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .bodyFatPercentage,
            unit: .percent(),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .bodyFat, metricName: "body_fat_pct",
                numericValue: value * 100, textValue: nil, unit: "percent",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(from: Date, to: Date) async throws -> [HealthMetric] {
        let userId = try currentUserId()
        let samples = try await executeQuantityQuery(
            typeIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: from, to: to
        )
        return samples.map { (date, value) in
            HealthMetric(
                id: UUID(), userId: userId, source: .appleHealthKit,
                category: .activeEnergy, metricName: "active_energy",
                numericValue: value, textValue: nil, unit: "kcal",
                recordedAt: date, recordedDate: recordedDate(from: date),
                metadata: nil, createdAt: nil
            )
        }
    }
}

// MARK: - HKWorkoutActivityType name

private extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "running"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .walking: return "walking"
        case .hiking: return "hiking"
        case .yoga: return "yoga"
        case .traditionalStrengthTraining: return "strength_training"
        case .functionalStrengthTraining: return "functional_strength"
        case .highIntensityIntervalTraining: return "hiit"
        default: return "other"
        }
    }
}

// MARK: - Errors

enum HealthKitServiceError: LocalizedError {
    case notAvailable
    case noAuthenticatedUser

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device."
        case .noAuthenticatedUser: return "No authenticated user — cannot create health metrics."
        }
    }
}
