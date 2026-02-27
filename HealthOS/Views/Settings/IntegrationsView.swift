import SwiftUI

/// Shows the status of each supported integration and lets the user
/// enable/disable HealthKit and Calendar (device-level permissions).
struct IntegrationsView: View {

    @State private var supabase = SupabaseService.shared
    @State private var healthKit = HealthKitService.shared
    @State private var calendar = CalendarService.shared

    @State private var integrations: [IntegrationProvider: ConnectedIntegration] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                IntegrationRow(
                    provider: .appleHealthKit,
                    isConnected: healthKit.isAuthorized,
                    lastSyncedAt: integrations[.appleHealthKit]?.lastSyncedAt,
                    onToggle: { await toggleHealthKit() }
                )
                IntegrationRow(
                    provider: .appleCalendar,
                    isConnected: calendar.isAuthorized,
                    lastSyncedAt: integrations[.appleCalendar]?.lastSyncedAt,
                    onToggle: { await toggleCalendar() }
                )
            } header: {
                Text("On-Device")
            } footer: {
                Text("HealthKit and Calendar data stays on your device and is synced to your coaching plan.")
            }

            Section {
                IntegrationRow(
                    provider: .whoop,
                    isConnected: integrations[.whoop]?.isActive == true,
                    lastSyncedAt: integrations[.whoop]?.lastSyncedAt,
                    onToggle: nil
                )
                IntegrationRow(
                    provider: .strava,
                    isConnected: integrations[.strava]?.isActive == true,
                    lastSyncedAt: integrations[.strava]?.lastSyncedAt,
                    onToggle: nil
                )
            } header: {
                Text("Cloud")
            } footer: {
                Text("Whoop and Strava connect via OAuth — coming in Phase 2.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadIntegrations() }
        .refreshable { await loadIntegrations() }
        .disabled(isLoading)
    }

    // MARK: - Load

    private func loadIntegrations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await supabase.getConnectedIntegrations()
            integrations = Dictionary(uniqueKeysWithValues: list.map { ($0.provider, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - HealthKit

    private func toggleHealthKit() async {
        guard !healthKit.isAuthorized else { return }
        do {
            _ = try await healthKit.requestAuthorization()
            await recordIntegration(provider: .appleHealthKit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Calendar

    private func toggleCalendar() async {
        guard !calendar.isAuthorized else { return }
        do {
            _ = try await calendar.requestAuthorization()
            await recordIntegration(provider: .appleCalendar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Record integration in Supabase

    private func recordIntegration(provider: IntegrationProvider) async {
        guard let userId = supabase.currentUser?.id else { return }
        let now = Date()
        let integration = ConnectedIntegration(
            id: UUID(),
            userId: userId,
            provider: provider,
            isActive: true,
            lastSyncedAt: now,
            providerUserId: nil,
            metadata: nil,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await supabase.upsertIntegration(integration)
            integrations[provider] = integration
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row

private struct IntegrationRow: View {

    let provider: IntegrationProvider
    let isConnected: Bool
    let lastSyncedAt: Date?
    let onToggle: (() async -> Void)?

    @State private var isToggling = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: providerIcon)
                .font(.title2)
                .foregroundStyle(isConnected ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.body)
                if let lastSyncedAt {
                    Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let onToggle, !isConnected {
                Button("Connect") {
                    Task {
                        isToggling = true
                        await onToggle()
                        isToggling = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isToggling)
            } else if onToggle == nil && !isConnected {
                Text("Phase 2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var providerIcon: String {
        switch provider {
        case .appleHealthKit: return "heart.fill"
        case .appleCalendar: return "calendar"
        case .whoop: return "waveform.path.ecg"
        case .strava: return "figure.run"
        }
    }
}
