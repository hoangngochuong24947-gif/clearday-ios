import AppIntents
import SwiftData

struct AddClearDayTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a ClearDay task"
    static let description = IntentDescription("Create a locally stored task with a practical work plan.")
    static let openAppWhenRun = false

    @Parameter(title: "Task")
    var taskTitle: String

    @Parameter(title: "Details")
    var details: String?

    @Parameter(title: "Estimated minutes")
    var estimatedMinutes: Int?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let createdTitle = try await MainActor.run {
            let task = try TaskStore.create(
                title: taskTitle,
                details: details ?? "",
                estimatedMinutes: estimatedMinutes ?? 60,
                in: AppDatabase.shared.container.mainContext
            )
            return task.title
        }
        return .result(dialog: "Added \(createdTitle) and built its plan.")
    }
}

struct OpenClearDayPlannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Plan a task in ClearDay"
    static let description = IntentDescription("Open ClearDay's planner with an optional task title.")
    static let openAppWhenRun = true

    @Parameter(title: "Task")
    var taskTitle: String?

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentHandoffCenter.shared.send(.composer(prefilledTitle: taskTitle ?? ""))
        }
        return .result()
    }
}

struct OpenTodayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open today's ClearDay plan"
    static let description = IntentDescription("Open ClearDay on today's scheduled work.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            IntentHandoffCenter.shared.send(.today)
        }
        return .result()
    }
}

struct CompleteNextClearDayTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete the next ClearDay task"
    static let description = IntentDescription("Mark the oldest open task complete without opening the app.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let completedTitle = try await MainActor.run {
            try TaskStore.completeNext(in: AppDatabase.shared.container.mainContext)
        }

        if let completedTitle {
            return .result(dialog: "Completed \(completedTitle).")
        }
        return .result(dialog: "There are no open tasks to complete.")
    }
}

struct ClearDayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddClearDayTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Capture work with \(.applicationName)",
            ],
            shortTitle: "Add task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenClearDayPlannerIntent(),
            phrases: [
                "Plan a task with \(.applicationName)",
                "Open the planner in \(.applicationName)",
            ],
            shortTitle: "Plan task",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: OpenTodayPlanIntent(),
            phrases: [
                "Show today's plan in \(.applicationName)",
            ],
            shortTitle: "Today's plan",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: CompleteNextClearDayTaskIntent(),
            phrases: [
                "Complete my next task in \(.applicationName)",
            ],
            shortTitle: "Complete next",
            systemImageName: "checkmark.circle"
        )
    }
}
