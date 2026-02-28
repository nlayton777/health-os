import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

interface NormalizeRequest {
  date: string; // ISO 8601 date (e.g., "2026-02-27")
  days?: number; // optional, default 1; fetch this many days starting from date
}

interface NormalizedWorkout {
  id: string;
  startTime: string; // ISO 8601
  durationMinutes: number;
  sportType: string;
  distance?: number;
  distanceUnit?: string;
  pace?: number;
  paceUnit?: string;
  power?: number;
  powerUnit?: string;
  strain?: number;
  avgHeartRate?: number;
  maxHeartRate?: number;
  hrZones?: {
    zone1Sec?: number;
    zone2Sec?: number;
    zone3Sec?: number;
    zone4Sec?: number;
    zone5Sec?: number;
  };
  source: "whoop" | "strava" | "apple_healthkit" | "merged";
  sources: string[];
  metadata?: Record<string, unknown>;
}

interface NormalizedSleep {
  durationHours?: number;
  startTime?: string; // ISO 8601
  endTime?: string; // ISO 8601
  performanceScore?: number;
  efficiency?: number;
  stages?: {
    rem?: number;
    deep?: number;
    light?: number;
    awake?: number;
  };
  source: "whoop" | "apple_healthkit";
  sources: string[];
}

interface NormalizedRecovery {
  score?: number;
  hrvRmsSd?: number;
  hrv?: number;
  hrvUnit?: string;
  spo2?: number;
  skinTempCelsius?: number;
  source: "whoop";
  sources: string[];
}

interface NormalizedStrain {
  score?: number;
  avgHeartRate?: number;
  maxHeartRate?: number;
  kilojoules?: number;
  source: "whoop";
  sources: string[];
}

interface NormalizedBody {
  weight?: number;
  weightUnit?: string;
  bodyFatPercent?: number;
  sources: string[];
}

interface NormalizedTrainingLoad {
  value?: number;
  windowStartDate?: string;
  windowEndDate?: string;
  activityCount?: number;
  source: "strava";
  sources: string[];
}

interface NormalizedDaySummary {
  date: string; // ISO 8601 date
  sleep?: NormalizedSleep;
  recovery?: NormalizedRecovery;
  strain?: NormalizedStrain;
  workouts?: NormalizedWorkout[];
  hrv?: {
    value: number;
    unit: string;
    source: "whoop" | "apple_healthkit";
  };
  restingHR?: {
    value: number;
    unit: string;
    source: "whoop" | "apple_healthkit";
  };
  body?: NormalizedBody;
  trainingLoad?: NormalizedTrainingLoad;
}

interface NormalizeResponse {
  success: boolean;
  data?: NormalizedDaySummary[];
  error?: string;
}

async function getSupabaseClient(authToken: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error("Missing Supabase environment variables");
  }

  return createClient(supabaseUrl, supabaseServiceKey);
}

async function getUserIdFromAuth(
  authToken: string,
  supabase: ReturnType<typeof createClient>
) {
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(authToken);

  if (error || !user) {
    throw new Error("Failed to get authenticated user");
  }

  return user.id;
}

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

function getDateString(date: Date): string {
  return date.toISOString().split("T")[0];
}

function parseDate(dateString: string): Date {
  return new Date(dateString + "T00:00:00Z");
}

async function getHealthMetrics(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  startDate: string,
  endDate: string
) {
  const { data, error } = await supabase
    .from("health_metrics")
    .select("*")
    .eq("user_id", userId)
    .gte("recorded_date", startDate)
    .lte("recorded_date", endDate)
    .order("recorded_date", { ascending: true })
    .order("recorded_at", { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch health metrics: ${error.message}`);
  }

  return data || [];
}

function buildNormalizedDaySummaries(metrics: any[]): Map<string, NormalizedDaySummary> {
  const daySummaries = new Map<string, NormalizedDaySummary>();

  // Initialize summaries for each day
  const uniqueDates = new Set(metrics.map((m) => m.recorded_date));
  uniqueDates.forEach((date) => {
    daySummaries.set(date, { date });
  });

  // Track which sources contributed to each field
  const dayContributors = new Map<string, Set<string>>();
  uniqueDates.forEach((date) => {
    dayContributors.set(date, new Set());
  });

  // Process metrics, applying deduplication rules
  const workoutsByDay = new Map<string, any[]>();
  const sleepByDay = new Map<string, any[]>();
  const hrvByDay = new Map<string, any[]>();
  const restingHRByDay = new Map<string, any[]>();

  // Group metrics by day and category
  for (const metric of metrics) {
    const date = metric.recorded_date;

    if (!workoutsByDay.has(date)) workoutsByDay.set(date, []);
    if (!sleepByDay.has(date)) sleepByDay.set(date, []);
    if (!hrvByDay.has(date)) hrvByDay.set(date, []);
    if (!restingHRByDay.has(date)) restingHRByDay.set(date, []);

    if (metric.category === "workout") {
      workoutsByDay.get(date)!.push(metric);
    } else if (metric.category === "sleep") {
      sleepByDay.get(date)!.push(metric);
    } else if (metric.category === "hrv") {
      hrvByDay.get(date)!.push(metric);
    } else if (
      metric.category === "heart_rate" &&
      metric.metric_name === "resting_heart_rate"
    ) {
      restingHRByDay.get(date)!.push(metric);
    }
  }

  // Process workouts with deduplication
  workoutsByDay.forEach((workouts, date) => {
    const deduplicatedWorkouts: NormalizedWorkout[] = [];
    const processedIndices = new Set<number>();

    // First pass: look for overlapping Whoop + Strava
    for (let i = 0; i < workouts.length; i++) {
      if (processedIndices.has(i)) continue;

      const workout = workouts[i];
      if (
        workout.source === "whoop" &&
        workout.metric_name === "whoop_workout"
      ) {
        // Look for overlapping Strava activity within 15 minutes
        const whoopStart = new Date(workout.recorded_at);
        let overlappingStrava = null;
        let overlappingStravaIdx = -1;

        for (let j = i + 1; j < workouts.length; j++) {
          if (processedIndices.has(j)) continue;

          const other = workouts[j];
          if (
            other.source === "strava" &&
            other.metric_name === "strava_activity"
          ) {
            const stravaStart = new Date(other.recorded_at);
            const diffMinutes =
              Math.abs(whoopStart.getTime() - stravaStart.getTime()) / 60000;

            if (diffMinutes <= 15) {
              overlappingStrava = other;
              overlappingStravaIdx = j;
              break;
            }
          }
        }

        if (overlappingStrava) {
          // Merge Whoop + Strava
          processedIndices.add(i);
          processedIndices.add(overlappingStravaIdx);

          const stravaMeta = overlappingStrava.metadata || {};
          const whoopMeta = workout.metadata || {};

          const mergedWorkout: NormalizedWorkout = {
            id: `merged_${workout.id}_${overlappingStrava.id}`,
            startTime: workout.recorded_at,
            durationMinutes: workout.numeric_value,
            sportType: overlappingStrava.text_value || workout.text_value,
            distance: stravaMeta.distance_km,
            distanceUnit: "km",
            pace: stravaMeta.distance_km
              ? (workout.numeric_value /stravaMeta.distance_km)
              : undefined,
            paceUnit: "min_per_km",
            power: stravaMeta.avg_power_watts,
            powerUnit: "watts",
            strain: whoopMeta.strain_score,
            avgHeartRate: whoopMeta.average_hr_bpm || stravaMeta.avg_heart_rate,
            maxHeartRate: whoopMeta.max_hr_bpm || stravaMeta.max_heart_rate,
            hrZones: whoopMeta.zone_durations
              ? {
                  zone1Sec: whoopMeta.zone_durations.zone_1_sec,
                  zone2Sec: whoopMeta.zone_durations.zone_2_sec,
                  zone3Sec: whoopMeta.zone_durations.zone_3_sec,
                  zone4Sec: whoopMeta.zone_durations.zone_4_sec,
                  zone5Sec: whoopMeta.zone_durations.zone_5_sec,
                }
              : undefined,
            source: "merged",
            sources: ["whoop", "strava"],
          };

          deduplicatedWorkouts.push(mergedWorkout);
          dayContributors.get(date)!.add("whoop");
          dayContributors.get(date)!.add("strava");
          continue;
        }
      }

      // If not merged, check if it's a HealthKit workout that should be dropped
      if (
        workout.source === "apple_healthkit" &&
        workout.metric_name === "workout_summary"
      ) {
        // Check if there's a Whoop or Strava workout at similar time
        const hkStart = new Date(workout.recorded_at);
        let hasDuplicate = false;

        for (let j = 0; j < workouts.length; j++) {
          if (i === j || processedIndices.has(j)) continue;
          const other = workouts[j];

          if (
            (other.source === "whoop" || other.source === "strava") &&
            (other.metric_name === "whoop_workout" ||
              other.metric_name === "strava_activity")
          ) {
            const otherStart = new Date(other.recorded_at);
            const diffMinutes =
              Math.abs(hkStart.getTime() - otherStart.getTime()) / 60000;

            if (diffMinutes <= 15) {
              hasDuplicate = true;
              break;
            }
          }
        }

        if (hasDuplicate) {
          processedIndices.add(i);
          continue;
        }
      }

      // Otherwise, add the workout as-is
      if (!processedIndices.has(i)) {
        const meta = workout.metadata || {};
        const normalized: NormalizedWorkout = {
          id: workout.id,
          startTime: workout.recorded_at,
          durationMinutes: workout.numeric_value,
          sportType: workout.text_value || "unknown",
          strain: meta.strain_score,
          avgHeartRate: meta.average_hr_bpm,
          maxHeartRate: meta.max_hr_bpm,
          hrZones: meta.zone_durations
            ? {
                zone1Sec: meta.zone_durations.zone_1_sec,
                zone2Sec: meta.zone_durations.zone_2_sec,
                zone3Sec: meta.zone_durations.zone_3_sec,
                zone4Sec: meta.zone_durations.zone_4_sec,
                zone5Sec: meta.zone_durations.zone_5_sec,
              }
            : undefined,
          source: workout.source,
          sources: [workout.source],
        };

        if (
          workout.metric_name === "strava_run_pace" ||
          workout.metric_name === "strava_ride_power"
        ) {
          // Skip derived metrics; we'll handle them with the main activity
          processedIndices.add(i);
          continue;
        }

        deduplicatedWorkouts.push(normalized);
        dayContributors.get(date)!.add(workout.source);
        processedIndices.add(i);
      }
    }

    const summary = daySummaries.get(date)!;
    if (deduplicatedWorkouts.length > 0) {
      summary.workouts = deduplicatedWorkouts;
    }
  });

  // Process sleep (prefer Whoop over HealthKit)
  sleepByDay.forEach((sleepMetrics, date) => {
    const summary = daySummaries.get(date)!;

    // Find Whoop sleep metrics first
    const whoopMetrics = sleepMetrics.filter((m) => m.source === "whoop");
    if (whoopMetrics.length > 0) {
      const durationMetric = whoopMetrics.find(
        (m) => m.metric_name === "whoop_sleep_duration"
      );
      const performanceMetric = whoopMetrics.find(
        (m) => m.metric_name === "whoop_sleep_performance"
      );

      const sleep: NormalizedSleep = {
        durationHours: durationMetric?.numeric_value,
        performanceScore: performanceMetric?.numeric_value,
        source: "whoop",
        sources: ["whoop"],
      };

      if (
        durationMetric &&
        durationMetric.metadata &&
        durationMetric.metadata.stage_rem_hours
      ) {
        sleep.stages = {
          rem: durationMetric.metadata.stage_rem_hours,
          deep: durationMetric.metadata.stage_deep_hours,
          light: durationMetric.metadata.stage_light_hours,
          awake: durationMetric.metadata.stage_awake_hours,
        };
      }

      if (performanceMetric && performanceMetric.metadata) {
        sleep.efficiency = performanceMetric.metadata.sleep_efficiency_pct;
      }

      summary.sleep = sleep;
      dayContributors.get(date)!.add("whoop");
    } else {
      // Fall back to HealthKit
      const hkMetrics = sleepMetrics.filter((m) => m.source === "apple_healthkit");
      if (hkMetrics.length > 0) {
        const hkSleep = hkMetrics[0];
        summary.sleep = {
          durationHours: hkSleep.numeric_value,
          source: "apple_healthkit",
          sources: ["apple_healthkit"],
        };
        dayContributors.get(date)!.add("apple_healthkit");
      }
    }
  });

  // Process recovery (Whoop only)
  for (const metric of metrics) {
    if (
      metric.category === "recovery" &&
      metric.metric_name === "whoop_recovery_score"
    ) {
      const date = metric.recorded_date;
      const summary = daySummaries.get(date)!;
      const meta = metric.metadata || {};

      summary.recovery = {
        score: metric.numeric_value,
        hrvRmsSd: meta.hrv_rmssd_ms,
        spo2: meta.spo2_pct,
        skinTempCelsius: meta.skin_temp_celsius,
        source: "whoop",
        sources: ["whoop"],
      };
      dayContributors.get(date)!.add("whoop");
    }
  }

  // Process strain (Whoop only)
  for (const metric of metrics) {
    if (
      metric.category === "strain" &&
      metric.metric_name === "whoop_strain_score"
    ) {
      const date = metric.recorded_date;
      const summary = daySummaries.get(date)!;
      const meta = metric.metadata || {};

      summary.strain = {
        score: metric.numeric_value,
        avgHeartRate: meta.average_hr_bpm,
        maxHeartRate: meta.max_hr_bpm,
        kilojoules: meta.kilojoules,
        source: "whoop",
        sources: ["whoop"],
      };
      dayContributors.get(date)!.add("whoop");
    }
  }

  // Process HRV (prefer Whoop RMSSD over HealthKit SDNN)
  hrvByDay.forEach((hrvMetrics, date) => {
    const summary = daySummaries.get(date)!;

    const whoopHRV = hrvMetrics.find((m) => m.metric_name === "whoop_hrv_rmssd");
    if (whoopHRV) {
      summary.hrv = {
        value: whoopHRV.numeric_value,
        unit: whoopHRV.unit,
        source: "whoop",
      };
      dayContributors.get(date)!.add("whoop");
    } else {
      const hkHRV = hrvMetrics.find((m) => m.metric_name === "hrv_sdnn");
      if (hkHRV) {
        summary.hrv = {
          value: hkHRV.numeric_value,
          unit: hkHRV.unit,
          source: "apple_healthkit",
        };
        dayContributors.get(date)!.add("apple_healthkit");
      }
    }
  });

  // Process resting HR (prefer Whoop over HealthKit)
  restingHRByDay.forEach((restingMetrics, date) => {
    const summary = daySummaries.get(date)!;

    const whoopResting = restingMetrics.find(
      (m) => m.metric_name === "whoop_resting_hr"
    );
    if (whoopResting) {
      summary.restingHR = {
        value: whoopResting.numeric_value,
        unit: whoopResting.unit,
        source: "whoop",
      };
      dayContributors.get(date)!.add("whoop");
    } else {
      const hkResting = restingMetrics.find(
        (m) => m.metric_name === "resting_heart_rate"
      );
      if (hkResting) {
        summary.restingHR = {
          value: hkResting.numeric_value,
          unit: hkResting.unit,
          source: "apple_healthkit",
        };
        dayContributors.get(date)!.add("apple_healthkit");
      }
    }
  });

  // Process body metrics (weight, body fat)
  for (const metric of metrics) {
    if (metric.category === "weight" || metric.category === "body_fat") {
      const date = metric.recorded_date;
      const summary = daySummaries.get(date)!;

      if (!summary.body) {
        summary.body = {
          sources: [],
        };
      }

      if (metric.category === "weight") {
        summary.body.weight = metric.numeric_value;
        summary.body.weightUnit = metric.unit;
      } else if (metric.category === "body_fat") {
        summary.body.bodyFatPercent = metric.numeric_value;
      }

      if (!summary.body.sources.includes(metric.source)) {
        summary.body.sources.push(metric.source);
      }
      dayContributors.get(date)!.add(metric.source);
    }
  }

  // Process training load (Strava)
  for (const metric of metrics) {
    if (
      metric.category === "training_load" &&
      metric.metric_name === "strava_training_load"
    ) {
      const date = metric.recorded_date;
      const summary = daySummaries.get(date)!;
      const meta = metric.metadata || {};

      summary.trainingLoad = {
        value: metric.numeric_value,
        windowStartDate: meta.window_start,
        windowEndDate: meta.window_end,
        activityCount: meta.activity_count,
        source: "strava",
        sources: ["strava"],
      };
      dayContributors.get(date)!.add("strava");
    }
  }

  return daySummaries;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ success: false, error: "Method not allowed" }),
        { status: 405 }
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing authorization" }),
        { status: 401 }
      );
    }

    const token = authHeader.slice(7);
    const supabase = await getSupabaseClient(token);
    const userId = await getUserIdFromAuth(token, supabase);

    const body = (await req.json()) as NormalizeRequest;
    const { date, days = 1 } = body;

    if (!date) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing date parameter" }),
        { status: 400 }
      );
    }

    // Parse the date and compute range
    const startDate = parseDate(date);
    const endDate = addDays(startDate, days);
    const startDateStr = getDateString(startDate);
    const endDateStr = getDateString(addDays(endDate, -1)); // Inclusive end date

    // Fetch health metrics for the date range
    const metrics = await getHealthMetrics(
      supabase,
      userId,
      startDateStr,
      endDateStr
    );

    // Build normalized day summaries
    const summariesMap = buildNormalizedDaySummaries(metrics);

    // Convert map to sorted array
    const summaries = Array.from(summariesMap.values()).sort(
      (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
    );

    return new Response(
      JSON.stringify({
        success: true,
        data: summaries,
      } as NormalizeResponse),
      {
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Normalize function error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500 }
    );
  }
});
