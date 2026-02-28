import Foundation

// MARK: - Protocol

protocol WhoopServiceProtocol {
    func buildAuthorizationURL() -> URL
    func handleOAuthCallback(code: String) async throws
    func syncData() async throws
    func disconnect() async throws
    var isConnected: Bool { get }
}

// MARK: - Implementation

@Observable
final class WhoopService: WhoopServiceProtocol {
    static let shared = WhoopService()

    private init() {}

    // MARK: - OAuth Configuration

    private var whoopClientId: String {
        // Should come from Config.xcconfig
        "whoop-client-id"
    }

    private var redirectUri: String {
        "app://whoop-callback"
    }

    // MARK: - Public Interface

    var isConnected: Bool {
        get {
            guard let integrations = try? SupabaseService.shared.getConnectedIntegrations(),
                  integrations.contains(where: { $0.provider == .whoop && $0.isActive }) else {
                return false
            }
            return true
        }
    }

    func buildAuthorizationURL() -> URL {
        var components = URLComponents(string: "https://api.prod.whoop.com/oauth/oauth2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: whoopClientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read:recovery read:sleep read:workout read:cycles read:profile"),
        ]

        guard let url = components.url else {
            fatalError("Invalid Whoop OAuth URL")
        }

        return url
    }

    func handleOAuthCallback(code: String) async throws {
        let response = try await callEdgeFunction(
            action: "oauth_callback",
            code: code,
            redirectUri: redirectUri
        )

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Unknown error"
            throw WhoopServiceError.oauthFailed(error)
        }
    }

    func syncData() async throws {
        let response = try await callEdgeFunction(action: "sync")

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Sync failed"
            throw WhoopServiceError.syncFailed(error)
        }
    }

    func disconnect() async throws {
        let response = try await callEdgeFunction(action: "disconnect")

        guard response["success"] as? Bool == true else {
            let error = response["error"] as? String ?? "Disconnect failed"
            throw WhoopServiceError.disconnectFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func callEdgeFunction(
        action: String,
        code: String? = nil,
        redirectUri: String? = nil
    ) async throws -> [String: Any] {
        guard let authToken = try await getAuthToken() else {
            throw WhoopServiceError.notAuthenticated
        }

        var payload: [String: Any] = ["action": action]
        if let code {
            payload["code"] = code
        }
        if let redirectUri {
            payload["redirect_uri"] = redirectUri
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        let supabaseURL = Config.supabaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let functionURL = "\(supabaseURL)/functions/v1/whoop-sync"

        var request = URLRequest(url: URL(string: functionURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopServiceError.invalidResponse
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw WhoopServiceError.httpError(httpResponse.statusCode)
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

enum WhoopServiceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)
    case oauthFailed(String)
    case syncFailed(String)
    case disconnectFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Supabase"
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
