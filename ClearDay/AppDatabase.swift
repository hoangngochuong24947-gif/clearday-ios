import Foundation
import SwiftData

@MainActor
final class AppDatabase {
    static let shared = AppDatabase()

    let container: ModelContainer

    private init() {
        let schema = Schema([ClearDayTask.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ClearDay's local store: \(error)")
        }
    }
}

@MainActor
enum TaskStore {
    @discardableResult
    static func create(
        title: String,
        details: String = "",
        estimatedMinutes: Int = 60,
        dueDate: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> ClearDayTask {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw TaskStoreError.emptyTitle
        }

        let clampedEstimate = min(max(estimatedMinutes, 15), 480)
        let plan = TaskPlanner.makePlan(
            title: trimmedTitle,
            details: details,
            estimatedMinutes: clampedEstimate,
            dueDate: dueDate,
            now: now,
            calendar: calendar
        )
        let task = ClearDayTask(
            title: trimmedTitle,
            detailsText: details.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            dueDate: dueDate,
            estimatedMinutes: clampedEstimate,
            plan: plan
        )
        context.insert(task)
        try context.save()
        return task
    }

    static func completeNext(in context: ModelContext, now: Date = .now) throws -> String? {
        var descriptor = FetchDescriptor<ClearDayTask>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\ClearDayTask.createdAt)]
        )
        descriptor.fetchLimit = 1

        guard let task = try context.fetch(descriptor).first else { return nil }
        task.isCompleted = true
        task.completedAt = now
        try context.save()
        return task.title
    }
}

enum TaskStoreError: LocalizedError {
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "A task needs a title."
        }
    }
}
