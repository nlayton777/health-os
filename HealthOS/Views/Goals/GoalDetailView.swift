import SwiftUI

struct GoalDetailView: View {

    let goal: Goal
    let onUpdate: () -> Void

    @State private var goalService = GoalService()
    @State private var editingGoal: Goal
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) var dismiss

    init(goal: Goal, onUpdate: @escaping () -> Void) {
        self.goal = goal
        self.onUpdate = onUpdate
        _editingGoal = State(initialValue: goal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $editingGoal.title)
                    TextField("Description", text: Binding(
                        get: { editingGoal.description ?? "" },
                        set: { editingGoal.description = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Target") {
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("Value", value: $editingGoal.targetValue, format: .number)
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField("Unit", text: $editingGoal.targetUnit)
                    DatePicker(
                        "Target Date",
                        selection: Binding(
                            get: { editingGoal.targetDate ?? Date() },
                            set: { editingGoal.targetDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }

                Section("Configuration") {
                    Picker("Priority", selection: $editingGoal.priority) {
                        ForEach(GoalPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    Picker("Status", selection: $editingGoal.status) {
                        ForEach(GoalStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    Stepper(
                        "Testing Every \(editingGoal.testingCadenceWeeks) weeks",
                        value: $editingGoal.testingCadenceWeeks,
                        in: 1...52
                    )
                }

                Section("Benchmark") {
                    TextField(
                        "Test Type",
                        text: Binding(
                            get: { editingGoal.benchmarkTestType ?? "" },
                            set: { editingGoal.benchmarkTestType = $0.isEmpty ? nil : $0 }
                        )
                    )
                }
            }
            .navigationTitle("Goal Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveGoal() }
                    }
                    .disabled(isSaving || editingGoal.title.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Delete Goal", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red.opacity(0.1))
                .cornerRadius(8)
                .padding()
                .confirmationDialog(
                    "Delete Goal?",
                    isPresented: $showDeleteConfirmation,
                    actions: {
                        Button("Delete", role: .destructive) {
                            Task { await deleteGoal() }
                        }
                    },
                    message: { Text("This action cannot be undone.") }
                )
            }
        }
    }

    private func saveGoal() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await goalService.updateGoal(editingGoal)
            onUpdate()
            dismiss()
        } catch {
            print("Error saving goal: \(error)")
        }
    }

    private func deleteGoal() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await goalService.deleteGoal(id: goal.id)
            onUpdate()
            dismiss()
        } catch {
            print("Error deleting goal: \(error)")
        }
    }
}

#Preview {
    let sampleGoal = Goal(
        id: UUID(),
        userId: UUID(),
        title: "Squat 405 lbs",
        description: "Full range of motion",
        category: .strength,
        targetValue: 405,
        targetUnit: "lbs",
        currentValue: 365,
        targetDate: Date().addingTimeInterval(86400 * 90),
        priority: .primary,
        benchmarkTestType: "1RM Test",
        testingCadenceWeeks: 8,
        status: .active,
        metadata: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    GoalDetailView(goal: sampleGoal, onUpdate: {})
}
