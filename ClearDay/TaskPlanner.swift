import Foundation

enum TaskPlanner {
    static func makePlan(
        title: String,
        details: String,
        estimatedMinutes: Int,
        dueDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PlanSnapshot {
        let totalMinutes = min(max(estimatedMinutes, 15), 480)
        let phases = phases(for: title, details: details, totalMinutes: totalMinutes)
        let durations = allocate(totalMinutes: totalMinutes, weights: phases.map(\.weight))

        var cursor = nextWorkingStart(onOrAfter: now, calendar: calendar)
        var blocks: [PlanBlock] = []

        for (index, pair) in zip(phases, durations).enumerated() {
            let (phase, duration) = pair
            let start = nextWorkingStart(onOrAfter: cursor, calendar: calendar)
            let end = addingWorkingMinutes(duration, to: start, calendar: calendar)
            blocks.append(
                PlanBlock(
                    id: index,
                    title: phase.title,
                    guidance: phase.guidance,
                    durationMinutes: duration,
                    scheduledStart: start,
                    scheduledEnd: end
                )
            )
            cursor = calendar.date(byAdding: .minute, value: 5, to: end) ?? end
        }

        let warning: String?
        if let dueDate, let end = blocks.last?.scheduledEnd, end > dueDate {
            warning = "The current estimate extends beyond the deadline. Reduce scope or move the due date."
        } else {
            warning = nil
        }

        return PlanSnapshot(
            generatedAt: now,
            dueDate: dueDate,
            blocks: blocks,
            warning: warning
        )
    }

    private struct Phase {
        let title: String
        let guidance: String
        let weight: Double
    }

    private static func phases(for title: String, details: String, totalMinutes: Int) -> [Phase] {
        let text = "\(title) \(details)".lowercased()
        let phases: [Phase]

        if containsAny(text, keywords: ["report", "proposal", "presentation", "write", "报告", "方案", "演示", "写作"]) {
            phases = [
                Phase(title: "Collect the evidence", guidance: "Gather the source material and define the audience.", weight: 0.22),
                Phase(title: "Shape the outline", guidance: "Choose the argument and the order that supports it.", weight: 0.18),
                Phase(title: "Create the first pass", guidance: "Draft quickly without polishing each sentence.", weight: 0.42),
                Phase(title: "Review and deliver", guidance: "Check clarity, facts, and the final delivery format.", weight: 0.18),
            ]
        } else if containsAny(text, keywords: ["meeting", "interview", "call", "会议", "面试", "沟通"]) {
            phases = [
                Phase(title: "Set the outcome", guidance: "Write the decision or answer this conversation needs.", weight: 0.20),
                Phase(title: "Prepare the inputs", guidance: "Collect context, questions, and supporting material.", weight: 0.35),
                Phase(title: "Run the conversation", guidance: "Keep notes beside the desired outcome.", weight: 0.30),
                Phase(title: "Close the loop", guidance: "Record decisions, owners, and the next follow-up.", weight: 0.15),
            ]
        } else if containsAny(text, keywords: ["learn", "study", "course", "exam", "学习", "复习", "课程", "考试"]) {
            phases = [
                Phase(title: "Map what matters", guidance: "List the concepts and define what success looks like.", weight: 0.15),
                Phase(title: "Learn one chunk", guidance: "Work through the smallest coherent section.", weight: 0.45),
                Phase(title: "Recall without notes", guidance: "Explain or solve from memory before checking.", weight: 0.25),
                Phase(title: "Capture the next gap", guidance: "Write the one thing to revisit in the next session.", weight: 0.15),
            ]
        } else {
            phases = [
                Phase(title: "Clarify the finish line", guidance: "Define the visible result that means this is done.", weight: 0.15),
                Phase(title: "Prepare the work", guidance: "Collect inputs and remove the first obvious blocker.", weight: 0.20),
                Phase(title: "Do the core work", guidance: "Focus on the highest-value part before polishing.", weight: 0.50),
                Phase(title: "Review and close", guidance: "Check the result, record follow-ups, and mark it done.", weight: 0.15),
            ]
        }

        let maximumPhaseCount = max(1, totalMinutes / 5)
        return Array(phases.prefix(maximumPhaseCount))
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }

    private static func allocate(totalMinutes: Int, weights: [Double]) -> [Int] {
        guard !weights.isEmpty else { return [] }

        var remaining = totalMinutes
        var result: [Int] = []

        for index in weights.indices {
            let remainingPhases = weights.count - index - 1
            if remainingPhases == 0 {
                result.append(remaining)
                break
            }

            let weighted = Int((Double(totalMinutes) * weights[index] / 5).rounded()) * 5
            let maximum = remaining - (remainingPhases * 5)
            let duration = min(max(weighted, 5), maximum)
            result.append(duration)
            remaining -= duration
        }

        return result
    }

    private static func nextWorkingStart(onOrAfter date: Date, calendar: Calendar) -> Date {
        var candidate = date

        while calendar.isDateInWeekend(candidate) {
            candidate = startOfNextDay(after: candidate, calendar: calendar)
        }

        let dayStart = calendar.startOfDay(for: candidate)
        let workStart = calendar.date(byAdding: .hour, value: 9, to: dayStart) ?? dayStart
        let workEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart) ?? dayStart

        if candidate < workStart {
            return workStart
        }
        if candidate >= workEnd {
            return nextWorkingStart(onOrAfter: startOfNextDay(after: candidate, calendar: calendar), calendar: calendar)
        }

        let minute = calendar.component(.minute, from: candidate)
        let remainder = minute % 5
        guard remainder != 0 else { return candidate }
        return calendar.date(byAdding: .minute, value: 5 - remainder, to: candidate) ?? candidate
    }

    private static func addingWorkingMinutes(_ minutes: Int, to start: Date, calendar: Calendar) -> Date {
        var remaining = minutes
        var cursor = nextWorkingStart(onOrAfter: start, calendar: calendar)

        while remaining > 0 {
            let dayStart = calendar.startOfDay(for: cursor)
            let workEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart) ?? cursor
            let available = max(0, calendar.dateComponents([.minute], from: cursor, to: workEnd).minute ?? 0)

            if remaining <= available {
                return calendar.date(byAdding: .minute, value: remaining, to: cursor) ?? cursor
            }

            remaining -= available
            cursor = nextWorkingStart(onOrAfter: startOfNextDay(after: cursor, calendar: calendar), calendar: calendar)
        }

        return cursor
    }

    private static func startOfNextDay(after date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }
}
