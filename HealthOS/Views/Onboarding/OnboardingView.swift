import SwiftUI

struct OnboardingView: View {

    @State private var supabase = SupabaseService.shared
    @State private var profile: Profile?

    // Form state
    @State private var displayName = ""
    @State private var dateOfBirth = Date()
    @State private var showDatePicker = false
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var sex: Profile.Sex?
    @State private var dailyTimeBudgetMin = 60

    @State private var isLoading = false
    @State private var errorMessage: String?

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    TextField("Display name", text: $displayName)

                    Picker("Biological sex", selection: $sex) {
                        Text("Prefer not to say").tag(Profile.Sex?.none)
                        ForEach(Profile.Sex.allCases, id: \.self) { option in
                            Text(option.displayName).tag(Profile.Sex?.some(option))
                        }
                    }

                    DatePicker(
                        "Date of birth",
                        selection: $dateOfBirth,
                        in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                        displayedComponents: .date
                    )
                }

                Section("Body Measurements (optional)") {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", text: $heightCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weightKg)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Stepper(
                        "Daily time budget: \(dailyTimeBudgetMin) min",
                        value: $dailyTimeBudgetMin,
                        in: 15...240,
                        step: 15
                    )
                } header: {
                    Text("Training Budget")
                } footer: {
                    Text("How many minutes per day can you commit to training?")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Set Up Your Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") {
                        Task { await saveProfile() }
                    }
                    .disabled(isLoading || displayName.isEmpty)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading { ProgressView().controlSize(.large) }
            }
        }
    }

    // MARK: - Save

    private func saveProfile() async {
        guard var profile = try? await supabase.getProfile() else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        profile.displayName = displayName.isEmpty ? nil : displayName
        profile.dateOfBirth = dateOfBirth
        profile.heightCm = Double(heightCm)
        profile.weightKg = Double(weightKg)
        profile.sex = sex
        profile.dailyTimeBudgetMin = dailyTimeBudgetMin
        profile.onboardingCompleted = true
        profile.updatedAt = Date()

        do {
            _ = try await supabase.updateProfile(profile)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Profile.Sex display name

private extension Profile.Sex {
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}
