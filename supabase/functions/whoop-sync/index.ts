import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const WHOOP_API_BASE = "https://api.prod.whoop.com/api";
const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";
const WHOOP_SCOPES = "read:recovery read:sleep read:workout read:cycles read:profile";

interface WhoopSyncRequest {
  action: "sync" | "oauth_callback" | "disconnect";
  code?: string;
  redirect_uri?: string;
}

interface WhoopSyncResponse {
  success: boolean;
  action: string;
  metrics_synced?: number;
  error?: string;
}

interface HealthMetric {
  user_id: string;
  source: string;
  category: string;
  metric_name: string;
  numeric_value?: number;
  text_value?: string;
  unit?: string;
  recorded_at: string;
  recorded_date: string;
  metadata: Record<string, unknown>;
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
);

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ success: false, error: "Method not allowed" }),
        { status: 405 }
      );
    }

    const authHeader = req.headers.get("authorization");
    const userId = extractUserIdFromAuth(authHeader);
    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401 }
      );
    }

    const body: WhoopSyncRequest = await req.json();

    switch (body.action) {
      case "oauth_callback":
        return await handleOAuthCallback(userId, body.code || "", body.redirect_uri || "");
      case "sync":
        return await handleSync(userId);
      case "disconnect":
        return await handleDisconnect(userId);
      default:
        return new Response(
          JSON.stringify({ success: false, error: "Invalid action" }),
          { status: 400 }
        );
    }
  } catch (error) {
    console.error("Error in whoop-sync:", error);
    return new Response(
      JSON.stringify({
        success: false,
        action: "unknown",
        error: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500 }
    );
  }
});

async function handleOAuthCallback(
  userId: string,
  code: string,
  redirectUri: string
): Promise<Response> {
  try {
    const clientId = Deno.env.get("WHOOP_CLIENT_ID");
    const clientSecret = Deno.env.get("WHOOP_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      throw new Error("Missing Whoop credentials");
    }

    const tokenResponse = await fetch(WHOOP_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
      }).toString(),
    });

    if (!tokenResponse.ok) {
      const errorData = await tokenResponse.json();
      throw new Error(`Token exchange failed: ${JSON.stringify(errorData)}`);
    }

    const tokenData = await tokenResponse.json();
    const expiresAt = new Date(Date.now() + tokenData.expires_in * 1000).toISOString();

    await supabase
      .from("connected_integrations")
      .upsert(
        {
          user_id: userId,
          provider: "whoop",
          access_token: tokenData.access_token,
          refresh_token: tokenData.refresh_token,
          token_expires_at: expiresAt,
          is_active: true,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,provider" }
      );

    return new Response(
      JSON.stringify({
        success: true,
        action: "oauth_callback",
      }),
      { status: 200 }
    );
  } catch (error) {
    console.error("OAuth callback error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        action: "oauth_callback",
        error: error instanceof Error ? error.message : "OAuth failed",
      }),
      { status: 400 }
    );
  }
}

async function handleSync(userId: string): Promise<Response> {
  try {
    const integration = await getIntegration(userId);
    if (!integration) {
      return new Response(
        JSON.stringify({
          success: false,
          action: "sync",
          error: "Whoop not connected",
        }),
        { status: 400 }
      );
    }

    let tokens = {
      accessToken: integration.access_token,
      refreshToken: integration.refresh_token,
      expiresAt: new Date(integration.token_expires_at),
    };

    // Refresh token if expired
    if (new Date() >= tokens.expiresAt) {
      tokens = await refreshAccessToken(tokens.refreshToken);
      await updateIntegrationTokens(userId, tokens);
    }

    // Determine sync range
    const cursor = await getSyncCursor(userId);
    const endDate = new Date();
    let startDate: Date;

    if (!cursor) {
      // First sync: backfill 14 days
      startDate = new Date(endDate);
      startDate.setDate(startDate.getDate() - 14);
    } else {
      // Recurring sync: last 2 days
      startDate = new Date(endDate);
      startDate.setDate(startDate.getDate() - 2);
    }

    const metrics: HealthMetric[] = [];

    // Fetch recovery data
    const recoveryData = await fetchWhoopEndpoint(
      tokens.accessToken,
      "/v1/recovery",
      formatDate(startDate),
      formatDate(endDate)
    );
    metrics.push(...mapRecoveryMetrics(userId, recoveryData));

    // Fetch sleep data
    const sleepData = await fetchWhoopEndpoint(
      tokens.accessToken,
      "/v1/sleep",
      formatDate(startDate),
      formatDate(endDate)
    );
    metrics.push(...mapSleepMetrics(userId, sleepData));

    // Fetch cycle/strain data
    const cycleData = await fetchWhoopEndpoint(
      tokens.accessToken,
      "/v1/cycle",
      formatDate(startDate),
      formatDate(endDate)
    );
    metrics.push(...mapCycleMetrics(userId, cycleData));

    // Fetch workout data
    const workoutData = await fetchWhoopEndpoint(
      tokens.accessToken,
      "/v1/workout",
      formatDate(startDate),
      formatDate(endDate)
    );
    metrics.push(...mapWorkoutMetrics(userId, workoutData));

    // Write metrics to database
    if (metrics.length > 0) {
      const { error } = await supabase.from("health_metrics").insert(metrics);
      if (error) {
        throw new Error(`Failed to insert metrics: ${error.message}`);
      }
    }

    // Update sync cursor with latest cycle_id
    if (cycleData && cycleData.records && cycleData.records.length > 0) {
      const latestCycleId = cycleData.records[cycleData.records.length - 1]?.id;
      if (latestCycleId) {
        await updateSyncCursor(userId, latestCycleId);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        action: "sync",
        metrics_synced: metrics.length,
      }),
      { status: 200 }
    );
  } catch (error) {
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        action: "sync",
        error: error instanceof Error ? error.message : "Sync failed",
      }),
      { status: 400 }
    );
  }
}

async function handleDisconnect(userId: string): Promise<Response> {
  try {
    const integration = await getIntegration(userId);
    if (!integration) {
      return new Response(
        JSON.stringify({
          success: true,
          action: "disconnect",
        }),
        { status: 200 }
      );
    }

    // Delete the integration (token revocation happens client-side via Whoop)
    await supabase
      .from("connected_integrations")
      .delete()
      .eq("user_id", userId)
      .eq("provider", "whoop");

    // Delete sync cursors
    await supabase
      .from("oauth_sync_cursors")
      .delete()
      .eq("user_id", userId)
      .eq("provider", "whoop");

    return new Response(
      JSON.stringify({
        success: true,
        action: "disconnect",
      }),
      { status: 200 }
    );
  } catch (error) {
    console.error("Disconnect error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        action: "disconnect",
        error: error instanceof Error ? error.message : "Disconnect failed",
      }),
      { status: 400 }
    );
  }
}

async function getIntegration(userId: string) {
  const { data } = await supabase
    .from("connected_integrations")
    .select("*")
    .eq("user_id", userId)
    .eq("provider", "whoop")
    .single();
  return data;
}

async function refreshAccessToken(
  refreshToken: string
): Promise<{ accessToken: string; refreshToken: string; expiresAt: Date }> {
  const clientId = Deno.env.get("WHOOP_CLIENT_ID");
  const clientSecret = Deno.env.get("WHOOP_CLIENT_SECRET");

  const response = await fetch(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: clientId || "",
      client_secret: clientSecret || "",
    }).toString(),
  });

  if (!response.ok) {
    throw new Error("Token refresh failed");
  }

  const data = await response.json();
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: new Date(Date.now() + data.expires_in * 1000),
  };
}

async function updateIntegrationTokens(
  userId: string,
  tokens: { accessToken: string; refreshToken: string; expiresAt: Date }
) {
  await supabase
    .from("connected_integrations")
    .update({
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      token_expires_at: tokens.expiresAt.toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId)
    .eq("provider", "whoop");
}

async function getSyncCursor(userId: string) {
  const { data } = await supabase
    .from("oauth_sync_cursors")
    .select("cursor_value")
    .eq("user_id", userId)
    .eq("provider", "whoop")
    .eq("cursor_type", "cycle_id")
    .single();
  return data?.cursor_value;
}

async function updateSyncCursor(userId: string, cycleId: string) {
  await supabase
    .from("oauth_sync_cursors")
    .upsert(
      {
        user_id: userId,
        provider: "whoop",
        cursor_type: "cycle_id",
        cursor_value: cycleId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id,provider,cursor_type" }
    );
}

async function fetchWhoopEndpoint(
  accessToken: string,
  endpoint: string,
  startDate: string,
  endDate: string
): Promise<any> {
  const url = new URL(`${WHOOP_API_BASE}${endpoint}`);
  url.searchParams.append("start", startDate);
  url.searchParams.append("end", endDate);

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Whoop API error: ${response.status}`);
  }

  return response.json();
}

function mapRecoveryMetrics(userId: string, data: any): HealthMetric[] {
  const metrics: HealthMetric[] = [];
  if (!data.records) return metrics;

  for (const record of data.records) {
    const date = new Date(record.created_at);
    const recordedAt = date.toISOString();
    const recordedDate = date.toISOString().split("T")[0];

    // Recovery score
    metrics.push({
      user_id: userId,
      source: "whoop",
      category: "recovery",
      metric_name: "whoop_recovery_score",
      numeric_value: record.score_state === "recovery_score" ? record.score : null,
      unit: "percent",
      recorded_at: recordedAt,
      recorded_date: recordedDate,
      metadata: {
        hrv_rmssd_ms: record.metrics?.hrv?.value,
        resting_heart_rate_bpm: record.metrics?.resting_heart_rate?.value,
        spo2_pct: record.metrics?.spo2?.value,
        skin_temp_celsius: record.metrics?.skin_temperature?.value,
        user_calibrating: record.metrics?.user_calibrating,
      },
    });

    // HRV
    if (record.metrics?.hrv?.value) {
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "hrv",
        metric_name: "whoop_hrv_rmssd",
        numeric_value: record.metrics.hrv.value,
        unit: "ms",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {
          recovery_id: record.id,
        },
      });
    }

    // Resting heart rate
    if (record.metrics?.resting_heart_rate?.value) {
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "heart_rate",
        metric_name: "whoop_resting_hr",
        numeric_value: record.metrics.resting_heart_rate.value,
        unit: "bpm",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {
          recovery_id: record.id,
        },
      });
    }

    // Respiratory rate
    if (record.metrics?.respiratory_rate?.value) {
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "respiratory_rate",
        metric_name: "whoop_respiratory_rate",
        numeric_value: record.metrics.respiratory_rate.value,
        unit: "breaths_per_min",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {},
      });
    }

    // Skin temperature
    if (record.metrics?.skin_temperature?.value) {
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "skin_temperature",
        metric_name: "whoop_skin_temp",
        numeric_value: record.metrics.skin_temperature.value,
        unit: "celsius",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {},
      });
    }
  }

  return metrics;
}

function mapSleepMetrics(userId: string, data: any): HealthMetric[] {
  const metrics: HealthMetric[] = [];
  if (!data.records) return metrics;

  for (const record of data.records) {
    const date = new Date(record.created_at);
    const recordedAt = date.toISOString();
    const recordedDate = date.toISOString().split("T")[0];

    // Sleep performance
    metrics.push({
      user_id: userId,
      source: "whoop",
      category: "sleep",
      metric_name: "whoop_sleep_performance",
      numeric_value: record.score_state === "sleep_performance" ? record.score : null,
      unit: "percent",
      recorded_at: recordedAt,
      recorded_date: recordedDate,
      metadata: {
        sleep_efficiency_pct: record.metrics?.sleep_efficiency?.value,
        disturbance_count: record.metrics?.disturbance_count?.value,
        time_in_bed_hours: record.metrics?.time_in_bed?.value,
        latency_minutes: record.metrics?.latency?.value,
        sleep_id: record.id,
      },
    });

    // Sleep duration
    if (record.metrics?.total_time_in_bed?.value) {
      const hoursSlept = record.metrics.total_time_in_bed.value / 3600;
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "sleep",
        metric_name: "whoop_sleep_duration",
        numeric_value: hoursSlept,
        unit: "hours",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {
          stage_rem_hours: (record.metrics?.rem_sleep?.value || 0) / 3600,
          stage_deep_hours: (record.metrics?.deep_sleep?.value || 0) / 3600,
          stage_light_hours: (record.metrics?.light_sleep?.value || 0) / 3600,
          stage_awake_hours: (record.metrics?.awake_time?.value || 0) / 3600,
        },
      });
    }

    // Sleep stages
    if (record.metrics) {
      const stageMap = [
        { stage: "rem", value: record.metrics.rem_sleep?.value },
        { stage: "deep", value: record.metrics.deep_sleep?.value },
        { stage: "light", value: record.metrics.light_sleep?.value },
        { stage: "awake", value: record.metrics.awake_time?.value },
      ];

      for (const { stage, value } of stageMap) {
        if (value) {
          metrics.push({
            user_id: userId,
            source: "whoop",
            category: "sleep",
            metric_name: "whoop_sleep_stage",
            text_value: stage,
            recorded_at: recordedAt,
            recorded_date: recordedDate,
            metadata: {
              start_iso: record.start,
              end_iso: record.end,
              duration_seconds: value,
            },
          });
        }
      }
    }
  }

  return metrics;
}

function mapCycleMetrics(userId: string, data: any): HealthMetric[] {
  const metrics: HealthMetric[] = [];
  if (!data.records) return metrics;

  for (const record of data.records) {
    const date = new Date(record.created_at);
    const recordedAt = date.toISOString();
    const recordedDate = date.toISOString().split("T")[0];

    if (record.score_state === "strain_score" && record.score) {
      metrics.push({
        user_id: userId,
        source: "whoop",
        category: "strain",
        metric_name: "whoop_strain_score",
        numeric_value: record.score,
        unit: "score",
        recorded_at: recordedAt,
        recorded_date: recordedDate,
        metadata: {
          average_hr_bpm: record.metrics?.average_heart_rate?.value,
          max_hr_bpm: record.metrics?.max_heart_rate?.value,
          kilojoules: record.metrics?.kilojoules?.value,
          cycle_id: record.id,
        },
      });
    }
  }

  return metrics;
}

function mapWorkoutMetrics(userId: string, data: any): HealthMetric[] {
  const metrics: HealthMetric[] = [];
  if (!data.records) return metrics;

  for (const record of data.records) {
    const date = new Date(record.created_at);
    const recordedAt = date.toISOString();
    const recordedDate = date.toISOString().split("T")[0];

    const durationMinutes = (record.metrics?.duration?.value || 0) / 60;
    const sportName = record.sport_name || "unknown";

    metrics.push({
      user_id: userId,
      source: "whoop",
      category: "workout",
      metric_name: "whoop_workout",
      numeric_value: durationMinutes,
      text_value: sportName,
      unit: "minutes",
      recorded_at: recordedAt,
      recorded_date: recordedDate,
      metadata: {
        strain_score: record.score_state === "strain_score" ? record.score : null,
        average_hr_bpm: record.metrics?.average_heart_rate?.value,
        max_hr_bpm: record.metrics?.max_heart_rate?.value,
        kilojoules: record.metrics?.kilojoules?.value,
        distance_meters: record.metrics?.distance?.value,
        zone_durations: {
          zone_1_sec: record.metrics?.zone_duration_z1?.value,
          zone_2_sec: record.metrics?.zone_duration_z2?.value,
          zone_3_sec: record.metrics?.zone_duration_z3?.value,
          zone_4_sec: record.metrics?.zone_duration_z4?.value,
          zone_5_sec: record.metrics?.zone_duration_z5?.value,
        },
      },
    });
  }

  return metrics;
}

function formatDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

function extractUserIdFromAuth(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const parts = authHeader.split(".");
  if (parts.length !== 3) return null;

  try {
    const payload = JSON.parse(atob(parts[1]));
    return payload.sub;
  } catch {
    return null;
  }
}
