import Foundation
import SwiftData

@Model
final class ClearDayTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var detailsText: String
    var createdAt: Date
    var dueDate: Date?
    var estimatedMinutes: Int
    var isCompleted: Bool
    var completedAt: Date?
    var planData: Data

    init(
        id: UUID = UUID(),
        title: String,
        detailsText: String = "",
        createdAt: Date = .now,
        dueDate: Date? = nil,
        estimatedMinutes: Int = 60,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        plan: PlanSnapshot
    ) {
        self.id = id
        self.title = title
        self.detailsText = detailsText
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.planData = (try? JSONEncoder().encode(plan)) ?? Data()
    }

    var plan: PlanSnapshot {
        get {
            (try? JSONDecoder().decode(PlanSnapshot.self, from: planData))
                ?? PlanSnapshot(generatedAt: createdAt, dueDate: dueDate, blocks: [], warning: nil)
        }
        set {
            planData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

struct PlanSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let dueDate: Date?
    let blocks: [PlanBlock]
    let warning: String?

    var totalMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }
}

struct PlanBlock: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let guidance: String
    let durationMinutes: Int
    let scheduledStart: Date
    let scheduledEnd: Date
}
