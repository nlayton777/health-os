import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const STRAVA_API_BASE = "https://www.strava.com/api/v3";
const STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token";

interface StravaSyncRequest {
  action: "oauth_callback" | "sync" | "disconnect";
  code?: string;
  userId?: string;
}

interface StravaSyncResponse {
  success: boolean;
  action: string;
  message: string;
  data?: Record<string, unknown>;
  error?: string;
  details?: string;
}

interface StravaActivity {
  id: number;
  name: string;
  type: string;
  start_date: string;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  elevation_gain: number;
  average_speed: number;
  max_speed: number;
  average_cadence: number;
  average_heartrate: number;
  max_heartrate: number;
  suffer_score: number;
  relative_effort: number;
  kudos_count: number;
  comment_count: number;
  athlete_count: number;
  average_watts?: number;
  max_watts?: number;
  weighted_average_watts?: number;
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

async function getActiveIntegration(
  supabase: ReturnType<typeof createClient>,
  userId: string
) {
  const { data, error } = await supabase
    .from("connected_integrations")
    .select("*")
    .eq("user_id", userId)
    .eq("provider", "strava")
    .eq("is_active", true)
    .single();

  if (error && error.code !== "PGRST116") {
    throw new Error(`Failed to fetch Strava integration: ${error.message}`);
  }

  return data;
}

async function refreshTokenIfNeeded(
  supabase: ReturnType<typeof createClient>,
  integration: Record<string, unknown>,
  userId: string
) {
  const metadata = integration.metadata as Record<string, unknown>;
  const tokenExpiresAt = metadata?.token_expires_at
    ? new Date(metadata.token_expires_at as string).getTime()
    : 0;
  const now = Date.now();

  if (tokenExpiresAt - now > 60000) {
    // Token still valid for more than 60 seconds
    return metadata?.access_token as string;
  }

  // Refresh token
  const clientId = Deno.env.get("STRAVA_CLIENT_ID");
  const clientSecret = Deno.env.get("STRAVA_CLIENT_SECRET");

  if (!clientId || !clientSecret) {
    throw new Error("Missing Strava credentials");
  }

  const refreshResponse = await fetch(STRAVA_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
      refresh_token: metadata?.refresh_token,
    }),
  });

  if (!refreshResponse.ok) {
    throw new Error("Failed to refresh Strava tokens");
  }

  const tokens = await refreshResponse.json();
  const expiresAt = new Date(
    Date.now() + tokens.expires_in * 1000
  ).toISOString();

  const newMetadata = {
    ...metadata,
    access_token: tokens.access_token,
    refresh_token: tokens.refresh_token,
    token_expires_at: expiresAt,
  };

  await supabase
    .from("connected_integrations")
    .update({
      metadata: newMetadata,
    })
    .eq("id", integration.id);

  return tokens.access_token;
}

async function handleOAuthCallback(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  code: string
): Promise<StravaSyncResponse> {
  const clientId = Deno.env.get("STRAVA_CLIENT_ID");
  const clientSecret = Deno.env.get("STRAVA_CLIENT_SECRET");
  const redirectUri = Deno.env.get("STRAVA_REDIRECT_URI");

  if (!clientId || !clientSecret || !redirectUri) {
    return {
      success: false,
      action: "oauth_callback",
      message: "Missing Strava configuration",
      error: "STRAVA_CONFIG_ERROR",
    };
  }

  try {
    const tokenResponse = await fetch(STRAVA_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      return {
        success: false,
        action: "oauth_callback",
        message: "Failed to exchange code for tokens",
        error: "TOKEN_EXCHANGE_ERROR",
      };
    }

    const tokens = await tokenResponse.json();
    const expiresAt = new Date(
      Date.now() + tokens.expires_in * 1000
    ).toISOString();

    // Upsert into connected_integrations
    const { error } = await supabase
      .from("connected_integrations")
      .upsert(
        {
          user_id: userId,
          provider: "strava",
          is_active: true,
          provider_user_id: String(tokens.athlete.id),
          last_synced_at: null,
          metadata: {
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            token_expires_at: expiresAt,
            athlete_name: tokens.athlete.firstname + " " + tokens.athlete.lastname,
          },
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,provider" }
      );

    if (error) {
      return {
        success: false,
        action: "oauth_callback",
        message: "Failed to save Strava credentials",
        error: "STORAGE_ERROR",
        details: error.message,
      };
    }

    return {
      success: true,
      action: "oauth_callback",
      message: "OAuth exchange complete",
      data: {
        redirectUrl: "app://strava-connected",
      },
    };
  } catch (err) {
    return {
      success: false,
      action: "oauth_callback",
      message: "Error during OAuth callback",
      error: "OAUTH_ERROR",
      details: err instanceof Error ? err.message : String(err),
    };
  }
}

async function syncActivities(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<StravaSyncResponse> {
  try {
    const integration = await getActiveIntegration(supabase, userId);

    if (!integration) {
      return {
        success: false,
        action: "sync",
        message: "Strava not connected",
        error: "NOT_CONNECTED",
      };
    }

    const accessToken = await refreshTokenIfNeeded(supabase, integration, userId);

    // Determine cursor (sync from)
    let fromUnixTime = Math.floor(Date.now() / 1000) - 30 * 24 * 60 * 60; // 30 days ago

    const { data: cursorData } = await supabase
      .from("oauth_sync_cursors")
      .select("*")
      .eq("user_id", userId)
      .eq("provider", "strava")
      .eq("cursor_type", "epoch")
      .single();

    if (cursorData) {
      fromUnixTime = parseInt(cursorData.cursor_value);
    }

    // Fetch activities from Strava API (paginated)
    const allActivities: StravaActivity[] = [];
    let page = 1;
    const pageSize = 30;
    let hasMore = true;

    while (hasMore) {
      const response = await fetch(
        `${STRAVA_API_BASE}/athlete/activities?after=${fromUnixTime}&per_page=${pageSize}&page=${page}`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      if (!response.ok) {
        return {
          success: false,
          action: "sync",
          message: "Failed to fetch Strava activities",
          error: "API_ERROR",
        };
      }

      const activities: StravaActivity[] = await response.json();

      if (activities.length === 0) {
        hasMore = false;
      } else {
        allActivities.push(...activities);
        page++;
      }
    }

    // Process activities and create metrics
    const metrics: HealthMetric[] = [];
    let totalSufferScore = 0;
    let activityCount = 0;

    // Calculate 7-day window for training load
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    for (const activity of allActivities) {
      const activityDate = new Date(activity.start_date);
      const durationMinutes = activity.elapsed_time / 60;

      // Main strava_activity metric
      metrics.push({
        user_id: userId,
        source: "strava",
        category: "workout",
        metric_name: "strava_activity",
        numeric_value: durationMinutes,
        text_value: activity.type,
        unit: "minutes",
        recorded_at: activity.start_date,
        recorded_date: activityDate.toISOString().split("T")[0],
        metadata: {
          strava_id: String(activity.id),
          activity_name: activity.name,
          activity_type: activity.type,
          distance_km: activity.distance / 1000,
          elevation_gain_m: activity.elevation_gain,
          avg_speed_kmh: activity.average_speed * 3.6,
          max_speed_kmh: activity.max_speed * 3.6,
          avg_cadence: activity.average_cadence || null,
          avg_heart_rate: activity.average_heartrate || null,
          max_heart_rate: activity.max_heartrate || null,
          suffer_score: activity.suffer_score || null,
          relative_effort: activity.relative_effort || null,
          kudos_count: activity.kudos_count,
          comment_count: activity.comment_count,
          athlete_count: activity.athlete_count,
        },
      });

      // Run-specific: strava_run_pace
      if (activity.type === "Run" && activity.distance > 0) {
        const paceMinPerKm = durationMinutes / (activity.distance / 1000);
        metrics.push({
          user_id: userId,
          source: "strava",
          category: "workout",
          metric_name: "strava_run_pace",
          numeric_value: paceMinPerKm,
          text_value: null,
          unit: "min_per_km",
          recorded_at: activity.start_date,
          recorded_date: activityDate.toISOString().split("T")[0],
          metadata: {
            strava_id: String(activity.id),
            distance_km: activity.distance / 1000,
            duration_minutes: durationMinutes,
            elevation_gain_m: activity.elevation_gain,
          },
        });
      }

      // Ride-specific: strava_ride_power (if power data available)
      if (activity.type === "Ride" && activity.average_watts) {
        metrics.push({
          user_id: userId,
          source: "strava",
          category: "workout",
          metric_name: "strava_ride_power",
          numeric_value: activity.average_watts,
          text_value: null,
          unit: "watts",
          recorded_at: activity.start_date,
          recorded_date: activityDate.toISOString().split("T")[0],
          metadata: {
            strava_id: String(activity.id),
            avg_power_watts: activity.average_watts,
            max_power_watts: activity.max_watts || null,
            normalized_power_watts: activity.weighted_average_watts || null,
            distance_km: activity.distance / 1000,
            duration_minutes: durationMinutes,
            elevation_gain_m: activity.elevation_gain,
          },
        });
      }

      // Track for training load
      if (activityDate >= sevenDaysAgo && activity.suffer_score) {
        totalSufferScore += activity.suffer_score;
        activityCount++;
      }
    }

    // Add strava_training_load metric
    if (allActivities.length > 0) {
      const latestActivity = allActivities[0];
      metrics.push({
        user_id: userId,
        source: "strava",
        category: "training_load",
        metric_name: "strava_training_load",
        numeric_value: totalSufferScore,
        text_value: null,
        unit: "suffer_score",
        recorded_at: new Date().toISOString(),
        recorded_date: new Date().toISOString().split("T")[0],
        metadata: {
          window_start: sevenDaysAgo.toISOString(),
          window_end: new Date().toISOString(),
          activity_count: activityCount,
        },
      });
    }

    // Insert metrics to database
    if (metrics.length > 0) {
      const { error: insertError } = await supabase
        .from("health_metrics")
        .insert(metrics);

      if (insertError) {
        return {
          success: false,
          action: "sync",
          message: "Failed to insert metrics",
          error: "DB_ERROR",
          details: insertError.message,
        };
      }
    }

    // Update cursor
    const latestActivityTime = Math.floor(
      new Date(allActivities[0]?.start_date || new Date()).getTime() / 1000
    );

    await supabase.from("oauth_sync_cursors").upsert(
      {
        user_id: userId,
        provider: "strava",
        cursor_type: "epoch",
        cursor_value: String(latestActivityTime),
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id,provider,cursor_type" }
    );

    return {
      success: true,
      action: "sync",
      message: "Sync complete",
      data: {
        metricsInserted: metrics.length,
        activitiesSynced: allActivities.length,
        trainingLoadValue: totalSufferScore,
        lastSyncedEpoch: latestActivityTime,
      },
    };
  } catch (err) {
    return {
      success: false,
      action: "sync",
      message: "Error during sync",
      error: "SYNC_ERROR",
      details: err instanceof Error ? err.message : String(err),
    };
  }
}

async function disconnect(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  accessToken: string
): Promise<StravaSyncResponse> {
  try {
    const integration = await getActiveIntegration(supabase, userId);

    if (!integration) {
      return {
        success: false,
        action: "disconnect",
        message: "Strava not connected",
        error: "NOT_CONNECTED",
      };
    }

    const token = await refreshTokenIfNeeded(supabase, integration, userId);

    // Call Strava deauthorize endpoint
    try {
      await fetch(`${STRAVA_API_BASE}/oauth/deauthorize`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });
    } catch {
      // Deauthorization might fail if token is already invalid
      // Continue with local cleanup anyway
    }

    // Delete from connected_integrations and oauth_sync_cursors
    await supabase
      .from("connected_integrations")
      .delete()
      .eq("user_id", userId)
      .eq("provider", "strava");

    await supabase
      .from("oauth_sync_cursors")
      .delete()
      .eq("user_id", userId)
      .eq("provider", "strava");

    return {
      success: true,
      action: "disconnect",
      message: "Strava integration removed",
    };
  } catch (err) {
    return {
      success: false,
      action: "disconnect",
      message: "Error during disconnect",
      error: "DISCONNECT_ERROR",
      details: err instanceof Error ? err.message : String(err),
    };
  }
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const authToken = req.headers.get("Authorization")?.replace("Bearer ", "");
    if (!authToken) {
      return new Response(
        JSON.stringify({
          success: false,
          action: "unknown",
          message: "Missing authorization token",
          error: "AUTH_ERROR",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = await getSupabaseClient(authToken);
    const userId = await getUserIdFromAuth(authToken, supabase);

    const body: StravaSyncRequest = await req.json();

    let response: StravaSyncResponse;

    switch (body.action) {
      case "oauth_callback":
        if (!body.code) {
          response = {
            success: false,
            action: "oauth_callback",
            message: "Missing authorization code",
            error: "INVALID_REQUEST",
          };
        } else {
          response = await handleOAuthCallback(supabase, userId, body.code);
        }
        break;

      case "sync":
        response = await syncActivities(supabase, userId);
        break;

      case "disconnect":
        response = await disconnect(supabase, userId, authToken);
        break;

      default:
        response = {
          success: false,
          action: "unknown",
          message: "Unknown action",
          error: "INVALID_ACTION",
        };
    }

    const statusCode = response.success ? 200 : 400;
    return new Response(JSON.stringify(response), {
      status: statusCode,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err) {
    const errorResponse: StravaSyncResponse = {
      success: false,
      action: "unknown",
      message: "Internal server error",
      error: "INTERNAL_ERROR",
      details: err instanceof Error ? err.message : String(err),
    };

    return new Response(JSON.stringify(errorResponse), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
