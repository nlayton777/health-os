import SwiftUI

@main
struct HealthOSApp: App {

    @State private var supabase = SupabaseService.shared
    @State private var authState: AuthState = .signedOut

    var body: some Scene {
        WindowGroup {
            RootView(authState: authState)
                .task {
                    for await state in supabase.observeAuthStateChanges() {
                        authState = state
                    }
                }
        }
    }
}

/// Routes to the appropriate top-level view based on auth state.
private struct RootView: View {
    let authState: AuthState

    var body: some View {
        switch authState {
        case .signedOut:
            LoginView()
        case .signedIn:
            HomeView()
        }
    }
}
