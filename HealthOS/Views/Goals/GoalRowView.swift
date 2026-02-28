import SwiftUI

struct GoalRowView: View {

    let goal: Goal

    var progressPercentage: Double {
        guard let current = goal.currentValue, goal.targetValue > 0 else {
            return 0
        }
        return min(Double(truncating: current as NSDecimalNumber) / Double(truncating: goal.targetValue as NSDecimalNumber), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 30, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let current = goal.currentValue {
                            Text("\(current) → \(goal.targetValue) \(goal.targetUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("→ \(goal.targetValue) \(goal.targetUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    priorityBadge
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progressPercentage)
                .tint(.blue)
        }
        .padding(.vertical, 8)
    }

    private var priorityBadge: some View {
        Text(goal.priority.displayName)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color(goal.priority.color)
                    .opacity(0.8)
            )
            .cornerRadius(4)
    }
}

#Preview {
    let sampleGoal = Goal(
        id: UUID(),
        userId: UUID(),
        title: "Squat 405 lbs",
        description: nil,
        category: .strength,
        targetValue: 405,
        targetUnit: "lbs",
        currentValue: 365,
        targetDate: Date().addingTimeInterval(86400 * 90),
        priority: .primary,
        benchmarkTestType: nil,
        testingCadenceWeeks: 8,
        status: .active,
        metadata: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    GoalRowView(goal: sampleGoal)
        .padding()
}
