import SwiftData
import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case today
        case tasks
    }

    private struct ComposerRequest: Identifiable {
        let id = UUID()
        let prefilledTitle: String
    }

    @State private var selectedTab: AppTab = .today
    @State private var composerRequest: ComposerRequest?
    @State private var handoffCenter = IntentHandoffCenter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView {
                    composerRequest = ComposerRequest(prefilledTitle: "")
                }
            }
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }
            .tag(AppTab.today)

            NavigationStack {
                TaskListView {
                    composerRequest = ComposerRequest(prefilledTitle: "")
                }
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(AppTab.tasks)
        }
        .tint(.indigo)
        .sheet(item: $composerRequest) { request in
            TaskComposerView(initialTitle: request.prefilledTitle)
        }
        .onAppear(perform: handlePendingIntent)
        .onChange(of: handoffCenter.pendingRequest?.id) {
            handlePendingIntent()
        }
    }

    private func handlePendingIntent() {
        guard let request = handoffCenter.take() else { return }
        switch request.destination {
        case let .composer(prefilledTitle):
            composerRequest = ComposerRequest(prefilledTitle: prefilledTitle)
        case .today:
            selectedTab = .today
        }
    }
}

private struct TodayView: View {
    private struct ScheduledBlock: Identifiable {
        let task: ClearDayTask
        let block: PlanBlock

        var id: String { "\(task.id.uuidString)-\(block.id)" }
    }

    @Query(sort: \ClearDayTask.createdAt, order: .reverse) private var tasks: [ClearDayTask]
    let addTask: () -> Void

    private var openTasks: [ClearDayTask] {
        tasks.filter { !$0.isCompleted }
    }

    private var todaysBlocks: [ScheduledBlock] {
        openTasks.flatMap { task in
            task.plan.blocks
                .filter { Calendar.current.isDateInToday($0.scheduledStart) }
                .map { ScheduledBlock(task: task, block: $0) }
        }
        .sorted { $0.block.scheduledStart < $1.block.scheduledStart }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(openTasks.isEmpty ? "A clear day starts here." : "\(openTasks.count) open tasks")
                        .font(.title2.bold())
                    Text("Plans stay on this device and remain useful without a subscription.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if todaysBlocks.isEmpty {
                ContentUnavailableView(
                    "No work scheduled today",
                    systemImage: "calendar",
                    description: Text("Add a task and ClearDay will turn it into focused blocks.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Today's blocks") {
                    ForEach(todaysBlocks) { scheduledBlock in
                        ScheduleBlockRow(task: scheduledBlock.task, block: scheduledBlock.block)
                    }
                }
            }
        }
        .navigationTitle("ClearDay")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addTask) {
                    Label("Add task", systemImage: "plus")
                }
                .accessibilityIdentifier("addTaskButton")
                .help("Add task")
            }
        }
    }
}

private struct ScheduleBlockRow: View {
    let task: ClearDayTask
    let block: PlanBlock

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(block.scheduledStart, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text("\(block.durationMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 58, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.body.weight(.semibold))
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                Text(block.guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClearDayTask.createdAt, order: .reverse) private var tasks: [ClearDayTask]
    let addTask: () -> Void

    var body: some View {
        List {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks yet",
                    systemImage: "checklist",
                    description: Text("Capture one outcome and preview a realistic plan.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(tasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        TaskRow(task: task, toggleCompletion: { toggle(task) })
                    }
                    .accessibilityIdentifier("taskRow.\(task.title)")
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addTask) {
                    Label("Add task", systemImage: "plus")
                }
                .accessibilityIdentifier("tasks.addTaskButton")
                .help("Add task")
            }
        }
    }

    private func toggle(_ task: ClearDayTask) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? .now : nil
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(tasks[offset])
        }
        try? modelContext.save()
    }
}

private struct TaskRow: View {
    let task: ClearDayTask
    let toggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                HStack(spacing: 8) {
                    Label("\(task.estimatedMinutes) min", systemImage: "clock")
                    if let dueDate = task.dueDate {
                        Label {
                            Text(dueDate, format: .dateTime.month().day())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct TaskDetailView: View {
    let task: ClearDayTask

    var body: some View {
        List {
            if !task.detailsText.isEmpty {
                Section("Notes") {
                    Text(task.detailsText)
                }
            }

            Section("Plan") {
                ForEach(task.plan.blocks) { block in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(block.title)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text("\(block.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(block.guidance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(block.scheduledStart, format: .dateTime.weekday(.abbreviated).hour().minute())
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.indigo)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ClearDayTask.self, inMemory: true)
}
