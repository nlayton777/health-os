import SwiftUI

struct AddGoalView: View {

    let onComplete: () -> Void

    @State private var goalService = GoalService()
    @State private var currentStep = 1
    @State private var selectedCategory: GoalCategory = .strength
    @State private var useTemplate = true
    @State private var selectedTemplate: GoalTemplate?
    @State private var customTitle = ""
    @State private var targetValue: Decimal = 0
    @State private var targetUnit = ""
    @State private var targetDate = Date().addingTimeInterval(86400 * 90)
    @State private var priority = GoalPriority.secondary
    @State private var benchmarkTestType = ""
    @State private var testingCadenceWeeks = 8
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss

    var availableTemplates: [GoalTemplate] {
        GoalTemplateLoader.shared.templates(for: selectedCategory)
    }

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
                    Button(action: {
                        selectedCategory = category
                        selectedTemplate = nil
                    }) {
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
                    if availableTemplates.isEmpty {
                        Text("No templates available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Template", selection: $selectedTemplate) {
                            Text("Select one...").tag(nil as GoalTemplate?)
                            ForEach(availableTemplates) { template in
                                Text(template.title).tag(template as GoalTemplate?)
                            }
                        }
                        .pickerStyle(.wheel)
                        if let template = selectedTemplate {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Type: \(template.benchmarkTestType)")
                                    .font(.caption)
                                Text("Unit: \(template.targetUnit)")
                                    .font(.caption)
                                Text("Test every \(template.defaultCadenceWeeks) weeks")
                                    .font(.caption)
                            }
                            .padding()
                            .background(.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
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
            return useTemplate ? (selectedTemplate != nil) : !customTitle.isEmpty
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

        let title: String
        let unit: String
        let benchmarkType: String?
        let cadence: Int

        if useTemplate, let template = selectedTemplate {
            title = template.title
            unit = template.targetUnit
            benchmarkType = template.benchmarkTestType
            cadence = template.defaultCadenceWeeks
        } else {
            title = customTitle
            unit = targetUnit
            benchmarkType = benchmarkTestType.isEmpty ? nil : benchmarkTestType
            cadence = testingCadenceWeeks
        }

        let newGoal = Goal(
            id: UUID(),
            userId: UUID(),
            title: title,
            description: nil,
            category: selectedCategory,
            targetValue: targetValue,
            targetUnit: unit,
            currentValue: nil,
            targetDate: targetDate,
            priority: priority,
            benchmarkTestType: benchmarkType,
            testingCadenceWeeks: cadence,
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

#Preview {
    AddGoalView(onComplete: {})
}
