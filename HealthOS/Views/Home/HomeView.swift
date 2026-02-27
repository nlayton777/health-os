import SwiftUI

/// Root view shown to authenticated users.
/// Hosts the main tab bar. Content screens are built in later phases.
struct HomeView: View {

    @State private var supabase = SupabaseService.shared
    @State private var profile: Profile?
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            TodayPlaceholderView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            Text("Progress — coming in Phase 4")
                .foregroundStyle(.secondary)
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .task { await loadProfile() }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
    }

    private func loadProfile() async {
        guard let loaded = try? await supabase.getProfile() else { return }
        profile = loaded
        if !loaded.onboardingCompleted {
            showOnboarding = true
        }
    }
}

// MARK: - Today placeholder

private struct TodayPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                Text("Daily coaching plan")
                    .font(.title2.bold())
                Text("Coming in Phase 3")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Today")
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {

    @State private var supabase = SupabaseService.shared
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Integrations") {
                    NavigationLink("Connected Apps") {
                        IntegrationsView()
                    }
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await signOut() }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func signOut() async {
        isSigningOut = true
        try? await supabase.signOut()
        isSigningOut = false
    }
}
