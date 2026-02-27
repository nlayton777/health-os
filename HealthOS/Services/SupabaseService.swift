import Foundation
import Supabase

// MARK: - Protocol

protocol SupabaseServiceProtocol {
    // Auth
    var currentUser: AuthUser? { get }
    var isAuthenticated: Bool { get }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser
    func signInWithEmail(email: String, password: String) async throws -> AuthUser
    func signUpWithEmail(email: String, password: String) async throws -> AuthUser
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

// MARK: - Implementation

/// Singleton service that owns the Supabase client and provides all
/// auth + database operations for the app.
///
/// All auth tokens are stored in the iOS Keychain automatically by
/// the Supabase Swift SDK. No manual session management is required.
@Observable
final class SupabaseService: SupabaseServiceProtocol {

    static let shared = SupabaseService()

    private let client: SupabaseClient

    private(set) var currentUser: AuthUser?

    var isAuthenticated: Bool { currentUser != nil }

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
        // Restore persisted session synchronously before the app renders.
        Task { await restoreSession() }
    }

    // MARK: - Session Restoration

    private func restoreSession() async {
        if let session = try? await client.auth.session {
            currentUser = AuthUser(
                id: session.user.id,
                email: session.user.email
            )
        }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthUser {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let user = AuthUser(id: session.user.id, email: session.user.email)
        currentUser = user
        return user
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        let session = try await client.auth.signIn(email: email, password: password)
        let user = AuthUser(id: session.user.id, email: session.user.email)
        currentUser = user
        return user
    }

    func signUpWithEmail(email: String, password: String) async throws -> AuthUser {
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else {
            throw SupabaseServiceError.noSession
        }
        let user = AuthUser(id: session.user.id, email: session.user.email)
        currentUser = user
        return user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    func observeAuthStateChanges() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    case .signedIn, .tokenRefreshed, .userUpdated:
                        if let session {
                            let user = AuthUser(id: session.user.id, email: session.user.email)
                            self.currentUser = user
                            continuation.yield(.signedIn(user: user))
                        }
                    case .signedOut, .passwordRecovery:
                        self.currentUser = nil
                        continuation.yield(.signedOut)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Profile

    func getProfile() async throws -> Profile {
        guard let userId = currentUser?.id else { throw SupabaseServiceError.notAuthenticated }
        return try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func updateProfile(_ profile: Profile) async throws -> Profile {
        return try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id)
            .single()
            .execute()
            .value
    }

    // MARK: - Connected Integrations

    func getConnectedIntegrations() async throws -> [ConnectedIntegration] {
        return try await client
            .from("connected_integrations")
            .select()
            .execute()
            .value
    }

    func upsertIntegration(_ integration: ConnectedIntegration) async throws {
        try await client
            .from("connected_integrations")
            .upsert(integration, onConflict: "user_id,provider")
            .execute()
    }

    func deleteIntegration(provider: IntegrationProvider) async throws {
        guard let userId = currentUser?.id else { throw SupabaseServiceError.notAuthenticated }
        try await client
            .from("connected_integrations")
            .delete()
            .eq("user_id", value: userId)
            .eq("provider", value: provider.rawValue)
            .execute()
    }

    // MARK: - Health Metrics

    func insertHealthMetrics(_ metrics: [HealthMetric]) async throws {
        guard !metrics.isEmpty else { return }
        try await client
            .from("health_metrics")
            .insert(metrics)
            .execute()
    }

    func getHealthMetrics(category: HealthCategory, from: Date, to: Date) async throws -> [HealthMetric] {
        let formatter = ISO8601DateFormatter()
        return try await client
            .from("health_metrics")
            .select()
            .eq("category", value: category.rawValue)
            .gte("recorded_date", value: formatter.string(from: from))
            .lte("recorded_date", value: formatter.string(from: to))
            .order("recorded_at", ascending: false)
            .execute()
            .value
    }
}

// MARK: - Errors

enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case noSession

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "No authenticated user."
        case .noSession: return "Sign-up succeeded but no session was returned."
        }
    }
}
