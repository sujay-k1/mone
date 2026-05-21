import Foundation
import Combine

@MainActor
final class MoneGoalStore: ObservableObject {
    @Published private(set) var goals: [MoneGoal] = []

    private let storageKey = "mone.goalPlanner.goals.v1"

    init() {
        load()
    }

    func add(_ goal: MoneGoal) {
        goals.insert(goal, at: 0)
        save()
    }

    func update(_ goal: MoneGoal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index] = goal
        save()
    }

    func delete(_ goal: MoneGoal) {
        goals.removeAll { $0.id == goal.id }
        save()
    }

    func resetForTesting() {
        goals = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            goals = []
            return
        }

        do {
            goals = try JSONDecoder().decode([MoneGoal].self, from: data)
        } catch {
            goals = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(goals)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save goals: \(error.localizedDescription)")
        }
    }
}
