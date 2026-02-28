import Foundation
import SwiftUI

// MARK: - Protocol

/// Protocol for goal CRUD operations.
protocol GoalServiceProtocol: Sendable {
    func getGoals(status: GoalStatus?) async throws -> [Goal]
    func createGoal(_ goal: Goal) async throws -> Goal
    func updateGoal(_ goal: Goal) async throws -> Goal
    func deleteGoal(id: UUID) async throws
}

/// Concrete implementation of goal service.
/// Delegates persistence to SupabaseService.
@Observable
final class GoalService: GoalServiceProtocol {

    private let supabase = SupabaseService.shared

    func getGoals(status: GoalStatus? = nil) async throws -> [Goal] {
        // TODO: Once SupabaseService.getGoals is implemented,
        // call it here and optionally filter by status.
        // For now, return an empty array to allow views to compile.
        return []
    }

    func createGoal(_ goal: Goal) async throws -> Goal {
        // TODO: Call SupabaseService.createGoal when available.
        return goal
    }

    func updateGoal(_ goal: Goal) async throws -> Goal {
        // TODO: Call SupabaseService.updateGoal when available.
        return goal
    }

    func deleteGoal(id: UUID) async throws {
        // TODO: Call SupabaseService.deleteGoal when available.
    }
}
