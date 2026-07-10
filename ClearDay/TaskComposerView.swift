import SwiftData
import SwiftUI

struct TaskComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var details = ""
    @State private var estimatedMinutes = 60
    @State private var hasDeadline = false
    @State private var dueDate = Date.now.addingTimeInterval(24 * 60 * 60)
    @State private var preview: PlanSnapshot?
    @State private var errorMessage: String?

    init(initialTitle: String = "") {
        _title = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Outcome") {
                    TextField("What needs to be done?", text: $title)
                        .accessibilityIdentifier("composer.title")
                    TextField("Useful context (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("composer.details")
                }

                Section("Timing") {
                    Stepper(value: $estimatedMinutes, in: 15...480, step: 15) {
                        LabeledContent("Estimate", value: "\(estimatedMinutes) min")
                    }
                    .accessibilityIdentifier("composer.estimate")

                    Toggle("Set a deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Due", selection: $dueDate, in: Date.now...)
                    }
                }

                Section {
                    Button(action: buildPreview) {
                        Label(preview == nil ? "Build plan" : "Rebuild plan", systemImage: "sparkles")
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier("composer.previewButton")
                } footer: {
                    Text("ClearDay uses a deterministic local planner today, so the result is private, explainable, and works offline.")
                }

                if let preview {
                    PlanPreviewSection(preview: preview)
                        .accessibilityIdentifier("planPreview")
                }
            }
            .navigationTitle("Plan a task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .accessibilityIdentifier("composer.saveButton")
                }
            }
            .alert("Could not save task", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .onChange(of: title) { preview = nil }
            .onChange(of: details) { preview = nil }
            .onChange(of: estimatedMinutes) { preview = nil }
            .onChange(of: hasDeadline) { preview = nil }
            .onChange(of: dueDate) { preview = nil }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedDueDate: Date? {
        hasDeadline ? dueDate : nil
    }

    private func buildPreview() {
        preview = TaskPlanner.makePlan(
            title: trimmedTitle,
            details: details,
            estimatedMinutes: estimatedMinutes,
            dueDate: selectedDueDate
        )
    }

    private func save() {
        do {
            try TaskStore.create(
                title: trimmedTitle,
                details: details,
                estimatedMinutes: estimatedMinutes,
                dueDate: selectedDueDate,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PlanPreviewSection: View {
    let preview: PlanSnapshot

    var body: some View {
        Section("Plan preview") {
            ForEach(preview.blocks) { block in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.indigo)
                        .frame(width: 12, height: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(block.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(block.durationMinutes)m")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(block.guidance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(block.scheduledStart, format: .dateTime.weekday(.abbreviated).hour().minute())
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.indigo)
                    }
                }
                .padding(.vertical, 2)
            }

            if let warning = preview.warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    TaskComposerView(initialTitle: "Prepare the launch brief")
        .modelContainer(for: ClearDayTask.self, inMemory: true)
}
