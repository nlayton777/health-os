import SwiftUI

struct GoalListView: View {

    @State private var goalService = GoalService()
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var showAddGoal = false
    @State private var selectedGoal: Goal?

    var body: some View {
        NavigationStack {
            ZStack {
                if goals.isEmpty && !isLoading {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Goals")
            .navigationDestination(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal) {
                    Task { await loadGoals() }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView {
                    Task { await loadGoals() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddGoal = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .task { await loadGoals() }
            .refreshable { await loadGoals() }
        }
    }

    private var list: some View {
        List {
            ForEach(GoalCategory.allCases, id: \.self) { category in
                let categoryGoals = goals.filter { $0.category == category && $0.status == .active }
                if !categoryGoals.isEmpty {
                    Section(header: Label(category.displayName, systemImage: category.icon)) {
                        ForEach(categoryGoals) { goal in
                            GoalRowView(goal: goal)
                                .onTapGesture { selectedGoal = goal }
                        }
                        .onDelete { indices in
                            Task {
                                for index in indices {
                                    try? await goalService.deleteGoal(id: categoryGoals[index].id)
                                }
                                await loadGoals()
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No goals yet")
                .font(.title2.bold())
            Text("Tap + to get started")
                .foregroundStyle(.secondary)
            Button(action: { showAddGoal = true }) {
                Label("Add Goal", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondary.opacity(0.1))
    }

    private func loadGoals() async {
        isLoading = true
        defer { isLoading = false }
        goals = (try? await goalService.getGoals(status: .active)) ?? []
    }
}

#Preview {
    GoalListView()
}
