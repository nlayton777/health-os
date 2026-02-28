import Foundation

// MARK: - Protocol

protocol StravaServiceProtocol {
    /// Whether Strava is currently connected.
    var isConnected: Bool { get async }

    /// Build the OAuth authorization URL.
    func buildAuthorizationURL() throws -> URL

    /// Exchange OAuth code for tokens and store in connected_integrations.
    func handleOAuthCallback(code: String) async throws

    /// Sync Strava activities and write to health_metrics.
    func syncData() async throws

    /// Deauthorize and delete the integration.
    func disconnect() async throws
}

// MARK: - Implementation

@Observable
final class StravaService: StravaServiceProtocol {
    static let shared = StravaService()

    private init() {}

    // MARK: - OAuth Configuration

    private var stravaClientId: String {
        "your-strava-client-id" // Should come from Config.xcconfig
    }

    private var stravaClientSecret: String {
        "your-strava-client-secret" // Should come from Config.xcconfig
    }

    private var redirectUri: String {
        "app://strava-callback"
    }

    // MARK: - Public Interface

    var isConnected: Bool {
        get async {
            do {
                let integrations = try await SupabaseService.shared.getConnectedIntegrations()
                return integrations.contains { $0.provider == .strava && $0.isActive }
            } catch {
                return false
            }
        }
    }

    func buildAuthorizationURL() throws -> URL {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: stravaClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read,activity:read_all"),
        ]

        guard let url = components.url else {
            throw StravaServiceError.invalidURL
        }

        return url
    }

    func handleOAuthCallback(code: String) async throws {
        let response = try await callEdgeFunction(
            action: "oauth_callback",
            code: code
        )

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Unknown error"
            throw StravaServiceError.oauthFailed(error)
        }
    }

    func syncData() async throws {
        let response = try await callEdgeFunction(action: "sync")

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Sync failed"
            throw StravaServiceError.syncFailed(error)
        }
    }

    func disconnect() async throws {
        let response = try await callEdgeFunction(action: "disconnect")

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Disconnect failed"
            throw StravaServiceError.disconnectFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func callEdgeFunction(
        action: String,
        code: String? = nil
    ) async throws -> [String: Any] {
        guard let authToken = try await getAuthToken() else {
            throw StravaServiceError.notAuthenticated
        }

        var payload: [String: Any] = ["action": action]
        if let code {
            payload["code"] = code
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(
            url: URL(string: "https://your-supabase-url.supabase.co/functions/v1/strava-sync")!
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaServiceError.invalidResponse
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw StravaServiceError.httpError(httpResponse.statusCode)
        }

        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return result ?? [:]
    }

    private func getAuthToken() async throws -> String? {
        let session = SupabaseService.shared
        return session.currentUser?.id.uuidString
    }
}

// MARK: - Errors

enum StravaServiceError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case oauthFailed(String)
    case syncFailed(String)
    case disconnectFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Supabase"
        case .invalidURL:
            return "Invalid Strava OAuth URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .oauthFailed(let error):
            return "OAuth failed: \(error)"
        case .syncFailed(let error):
            return "Sync failed: \(error)"
        case .disconnectFailed(let error):
            return "Disconnect failed: \(error)"
        }
    }
}
