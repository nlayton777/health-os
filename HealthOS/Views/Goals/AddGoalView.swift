import SwiftUI

struct AddGoalView: View {

    let onComplete: () -> Void

    @State private var goalService = GoalService()
    @State private var currentStep = 1
    @State private var selectedCategory: GoalCategory = .strength
    @State private var useTemplate = true
    @State private var selectedTemplate: GoalTemplate = .benchPress
    @State private var customTitle = ""
    @State private var targetValue: Decimal = 0
    @State private var targetUnit = ""
    @State private var targetDate = Date().addingTimeInterval(86400 * 90)
    @State private var priority = GoalPriority.secondary
    @State private var benchmarkTestType = ""
    @State private var testingCadenceWeeks = 8
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(currentStep) / 4.0)
                    .padding()

                ZStack {
                    switch currentStep {
                    case 1:
                        step1CategorySelection
                    case 2:
                        step2TemplateSelection
                    case 3:
                        step3TargetConfiguration
                    case 4:
                        step4BenchmarkConfiguration
                    default:
                        Text("Unknown step")
                    }
                }
                .transition(.opacity)

                HStack(spacing: 12) {
                    if currentStep > 1 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Button(currentStep == 4 ? "Create Goal" : "Next") {
                        if currentStep == 4 {
                            Task { await createGoal() }
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || !isCurrentStepValid)
                }
                .padding()
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var step1CategorySelection: some View {
        VStack(spacing: 20) {
            Text("Choose a category")
                .font(.headline)
            VStack(spacing: 12) {
                ForEach(GoalCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        VStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.title)
                            Text(category.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.1))
                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    private var step2TemplateSelection: some View {
        VStack(spacing: 16) {
            Picker("", selection: $useTemplate) {
                Text("Use Template").tag(true)
                Text("Custom Goal").tag(false)
            }
            .pickerStyle(.segmented)

            if useTemplate {
                VStack(spacing: 12) {
                    Text("Select a template")
                        .font(.headline)
                    Picker("Template", selection: $selectedTemplate) {
                        ForEach(GoalTemplate.allCases, id: \.self) { template in
                            Text(template.title).tag(template)
                        }
                    }
                    .pickerStyle(.wheel)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption.bold())
                        Text(selectedTemplate.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Create custom goal")
                        .font(.headline)
                    TextField("Goal title", text: $customTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var step3TargetConfiguration: some View {
        VStack(spacing: 16) {
            Text("Set your target")
                .font(.headline)

            Form {
                Section("Target Value") {
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("0", value: $targetValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("Unit (e.g., lbs, miles)", text: $targetUnit)
                }

                Section("Timeline") {
                    DatePicker(
                        "Target Date",
                        selection: $targetDate,
                        displayedComponents: .date
                    )
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(GoalPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                }
            }
        }
    }

    private var step4BenchmarkConfiguration: some View {
        VStack(spacing: 16) {
            Text("Testing Schedule")
                .font(.headline)

            Form {
                Section("Benchmark Test") {
                    TextField("Test type (e.g., 1RM Test, DEXA Scan)", text: $benchmarkTestType)
                }

                Section("Testing Cadence") {
                    Stepper(
                        "Every \(testingCadenceWeeks) weeks",
                        value: $testingCadenceWeeks,
                        in: 1...52
                    )
                    Text("You'll check progress every \(testingCadenceWeeks) weeks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 1:
            return true
        case 2:
            return useTemplate || !customTitle.isEmpty
        case 3:
            return targetValue > 0 && !targetUnit.isEmpty
        case 4:
            return true
        default:
            return false
        }
    }

    private func createGoal() async {
        isSaving = true
        defer { isSaving = false }

        let title = useTemplate ? selectedTemplate.title : customTitle
        let newGoal = Goal(
            id: UUID(),
            userId: UUID(),
            title: title,
            description: selectedTemplate.description,
            category: selectedCategory,
            targetValue: targetValue,
            targetUnit: targetUnit,
            currentValue: nil,
            targetDate: targetDate,
            priority: priority,
            benchmarkTestType: benchmarkTestType.isEmpty ? nil : benchmarkTestType,
            testingCadenceWeeks: testingCadenceWeeks,
            status: .active,
            metadata: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            _ = try await goalService.createGoal(newGoal)
            onComplete()
            dismiss()
        } catch {
            print("Error creating goal: \(error)")
        }
    }
}

// MARK: - Goal Templates

enum GoalTemplate: CaseIterable {
    case benchPress
    case squat
    case deadlift
    case fiveK
    case subTenPercentBodyFat
    case improveHRV

    var title: String {
        switch self {
        case .benchPress: "Bench Press Max"
        case .squat: "Squat Max"
        case .deadlift: "Deadlift Max"
        case .fiveK: "Sub-22:00 5K"
        case .subTenPercentBodyFat: "Get to 10% Body Fat"
        case .improveHRV: "Improve HRV to 80ms"
        }
    }

    var description: String {
        switch self {
        case .benchPress: "Increase your maximum barbell bench press."
        case .squat: "Increase your maximum back squat lift."
        case .deadlift: "Increase your maximum deadlift lift."
        case .fiveK: "Run a 5K in under 22 minutes."
        case .subTenPercentBodyFat: "Achieve lean physique at 10% body fat."
        case .improveHRV: "Improve heart rate variability for better recovery."
        }
    }

    var defaultUnit: String {
        switch self {
        case .benchPress, .squat, .deadlift: "lbs"
        case .fiveK: "minutes"
        case .subTenPercentBodyFat: "%"
        case .improveHRV: "ms"
        }
    }
}

#Preview {
    AddGoalView(onComplete: {})
}
