import Foundation
import SwiftData
import Testing
@testable import ClearDay

struct ClearDayTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func plannerIsDeterministicAndPreservesEstimate() throws {
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 8,
            minute: 50
        )))

        let first = TaskPlanner.makePlan(
            title: "Write launch report",
            details: "Use customer interviews",
            estimatedMinutes: 95,
            dueDate: nil,
            now: now,
            calendar: calendar
        )
        let second = TaskPlanner.makePlan(
            title: "Write launch report",
            details: "Use customer interviews",
            estimatedMinutes: 95,
            dueDate: nil,
            now: now,
            calendar: calendar
        )

        #expect(first.blocks.map(\.title) == second.blocks.map(\.title))
        #expect(first.blocks.map(\.durationMinutes) == second.blocks.map(\.durationMinutes))
        #expect(first.blocks.map(\.scheduledStart) == second.blocks.map(\.scheduledStart))
        #expect(first.totalMinutes == 95)
        #expect(first.blocks.first?.scheduledStart == calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 13, hour: 9)
        ))
    }

    @Test
    func plannerMovesWorkAcrossTheEveningBoundary() throws {
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 17,
            minute: 45
        )))

        let plan = TaskPlanner.makePlan(
            title: "Prepare release",
            details: "",
            estimatedMinutes: 120,
            dueDate: nil,
            now: now,
            calendar: calendar
        )

        #expect(plan.totalMinutes == 120)
        #expect(plan.blocks.contains { calendar.component(.day, from: $0.scheduledEnd) == 14 })
        #expect(plan.blocks.allSatisfy { !calendar.isDateInWeekend($0.scheduledStart) })
    }

    @Test @MainActor
    func taskStorePersistsTheGeneratedPlan() throws {
        let schema = Schema([ClearDayTask.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let task = try TaskStore.create(
            title: "Prepare demo",
            estimatedMinutes: 75,
            in: container.mainContext
        )
        let storedTasks = try container.mainContext.fetch(FetchDescriptor<ClearDayTask>())

        #expect(storedTasks.count == 1)
        #expect(task.plan.totalMinutes == 75)
        #expect(!task.plan.blocks.isEmpty)
    }
}
