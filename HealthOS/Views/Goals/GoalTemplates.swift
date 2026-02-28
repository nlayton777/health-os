import Foundation

/// Goal template loaded from phase-2-goal-templates.json
struct GoalTemplate: Codable, Identifiable {
    let title: String
    let targetUnit: String
    let benchmarkTestType: String
    let defaultCadenceWeeks: Int

    enum CodingKeys: String, CodingKey {
        case title
        case targetUnit = "target_unit"
        case benchmarkTestType = "benchmark_test_type"
        case defaultCadenceWeeks = "default_cadence_weeks"
    }

    var id: String { title }
}

/// Container for templates grouped by category
struct GoalTemplateGroup: Codable {
    let category: String
    let templates: [GoalTemplate]
}

/// Loads and manages goal templates
final class GoalTemplateLoader {
    static let shared = GoalTemplateLoader()

    private(set) var templatesByCategory: [String: [GoalTemplate]] = [:]
    private var isLoaded = false

    init() {
        loadTemplates()
    }

    private func loadTemplates() {
        guard !isLoaded else { return }

        guard let url = Bundle.main.url(forResource: "goal-templates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Warning: Could not load goal-templates.json")
            return
        }

        do {
            let groups = try JSONDecoder().decode([GoalTemplateGroup].self, from: data)
            for group in groups {
                templatesByCategory[group.category] = group.templates
            }
            isLoaded = true
        } catch {
            print("Error decoding goal-templates.json: \(error)")
        }
    }

    func templates(for category: GoalCategory) -> [GoalTemplate] {
        templatesByCategory[category.rawValue] ?? []
    }
}
