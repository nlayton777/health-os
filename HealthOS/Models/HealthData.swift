import Foundation

/// Response from the normalize Edge Function containing aggregated health data per day
struct NormalizeResponse: Codable {
    let success: Bool
    let data: [NormalizedDaySummary]?
    let error: String?
}

/// A single day's aggregated health data from all sources (Whoop, Strava, HealthKit)
struct NormalizedDaySummary: Codable, Identifiable {
    let id: String
    let date: String // ISO 8601 date (e.g., "2026-02-27")
    let sleep: NormalizedSleep?
    let recovery: NormalizedRecovery?
    let strain: NormalizedStrain?
    let workouts: [NormalizedWorkout]?
    let hrv: HRVData?
    let restingHR: RestingHRData?
    let body: NormalizedBody?
    let trainingLoad: NormalizedTrainingLoad?

    enum CodingKeys: String, CodingKey {
        case date
        case sleep
        case recovery
        case strain
        case workouts
        case hrv
        case restingHR = "resting_hr"
        case body
        case trainingLoad = "training_load"
    }

    // Computed property for id to conform to Identifiable
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.id = date
        self.sleep = try container.decodeIfPresent(NormalizedSleep.self, forKey: .sleep)
        self.recovery = try container.decodeIfPresent(NormalizedRecovery.self, forKey: .recovery)
        self.strain = try container.decodeIfPresent(NormalizedStrain.self, forKey: .strain)
        self.workouts = try container.decodeIfPresent([NormalizedWorkout].self, forKey: .workouts)
        self.hrv = try container.decodeIfPresent(HRVData.self, forKey: .hrv)
        self.restingHR = try container.decodeIfPresent(RestingHRData.self, forKey: .restingHR)
        self.body = try container.decodeIfPresent(NormalizedBody.self, forKey: .body)
        self.trainingLoad = try container.decodeIfPresent(NormalizedTrainingLoad.self, forKey: .trainingLoad)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(sleep, forKey: .sleep)
        try container.encodeIfPresent(recovery, forKey: .recovery)
        try container.encodeIfPresent(strain, forKey: .strain)
        try container.encodeIfPresent(workouts, forKey: .workouts)
        try container.encodeIfPresent(hrv, forKey: .hrv)
        try container.encodeIfPresent(restingHR, forKey: .restingHR)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(trainingLoad, forKey: .trainingLoad)
    }
}

/// Sleep data with Whoop preferred over HealthKit
struct NormalizedSleep: Codable {
    let durationHours: Double?
    let startTime: String? // ISO 8601
    let endTime: String? // ISO 8601
    let performanceScore: Double? // 0-100
    let efficiency: Double? // percentage
    let stages: SleepStages?
    let source: String // "whoop" or "apple_healthkit"
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case durationHours = "duration_hours"
        case startTime = "start_time"
        case endTime = "end_time"
        case performanceScore = "performance_score"
        case efficiency
        case stages
        case source
        case sources
    }
}

struct SleepStages: Codable {
    let rem: Double?
    let deep: Double?
    let light: Double?
    let awake: Double?
}

/// Recovery metrics from Whoop
struct NormalizedRecovery: Codable {
    let score: Double? // 0-100
    let hrvRmsSd: Double? // HRV in milliseconds
    let hrv: Double?
    let hrvUnit: String?
    let spo2: Double? // SpO2 percentage
    let skinTempCelsius: Double?
    let source: String // "whoop"
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case score
        case hrvRmsSd = "hrv_rms_sd"
        case hrv
        case hrvUnit = "hrv_unit"
        case spo2
        case skinTempCelsius = "skin_temp_celsius"
        case source
        case sources
    }
}

/// Daily strain score from Whoop
struct NormalizedStrain: Codable {
    let score: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let kilojoules: Double?
    let source: String // "whoop"
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case score
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case kilojoules
        case source
        case sources
    }
}

/// A deduplicated workout from any source
struct NormalizedWorkout: Codable, Identifiable {
    let id: String
    let startTime: String // ISO 8601
    let durationMinutes: Double
    let sportType: String
    let distance: Double?
    let distanceUnit: String?
    let pace: Double?
    let paceUnit: String?
    let power: Double?
    let powerUnit: String?
    let strain: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let hrZones: HRZones?
    let source: String // "whoop", "strava", "apple_healthkit", or "merged"
    let sources: [String]
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case durationMinutes = "duration_minutes"
        case sportType = "sport_type"
        case distance
        case distanceUnit = "distance_unit"
        case pace
        case paceUnit = "pace_unit"
        case power
        case powerUnit = "power_unit"
        case strain
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case hrZones = "hr_zones"
        case source
        case sources
        case metadata
    }
}

struct HRZones: Codable {
    let zone1Sec: Double?
    let zone2Sec: Double?
    let zone3Sec: Double?
    let zone4Sec: Double?
    let zone5Sec: Double?

    enum CodingKeys: String, CodingKey {
        case zone1Sec = "zone_1_sec"
        case zone2Sec = "zone_2_sec"
        case zone3Sec = "zone_3_sec"
        case zone4Sec = "zone_4_sec"
        case zone5Sec = "zone_5_sec"
    }
}

/// HRV data with source indication (Whoop RMSSD preferred over HealthKit SDNN)
struct HRVData: Codable {
    let value: Double
    let unit: String
    let source: String // "whoop" or "apple_healthkit"
}

/// Resting heart rate with source indication (Whoop preferred over HealthKit)
struct RestingHRData: Codable {
    let value: Double
    let unit: String
    let source: String // "whoop" or "apple_healthkit"
}

/// Body composition metrics (weight, body fat)
struct NormalizedBody: Codable {
    let weight: Double?
    let weightUnit: String?
    let bodyFatPercent: Double?
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case weight
        case weightUnit = "weight_unit"
        case bodyFatPercent = "body_fat_percent"
        case sources
    }
}

/// Training load from Strava (7-day rolling sum)
struct NormalizedTrainingLoad: Codable {
    let value: Double?
    let windowStartDate: String?
    let windowEndDate: String?
    let activityCount: Int?
    let source: String // "strava"
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case value
        case windowStartDate = "window_start_date"
        case windowEndDate = "window_end_date"
        case activityCount = "activity_count"
        case source
        case sources
    }
}

/// A type-erased Codable wrapper for dynamic JSON values
enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}
