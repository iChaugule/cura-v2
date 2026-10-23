import SwiftUI
import Observation

@MainActor
@Observable
final class TaskChecklistViewModel {
    var tasks: [BookingTask]
    var isSaving: Bool = false
    var syncState: SyncState = .synced
    var taskForDeclineReason: BookingTask? = nil
    var declineReasonText: String = ""

    init(booking: Booking) {
        self.tasks = booking.tasks
    }

    var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    var totalCount: Int { tasks.count }
    var progress: Double { Double(completedCount) / Double(max(1, totalCount)) }

    func toggle(_ task: BookingTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if tasks[idx].isMedicationRelated { return } // medication always uses explicit confirm
        if tasks[idx].status == .completed {
            tasks[idx].status = .scheduled
            tasks[idx].completedAt = nil
        } else {
            tasks[idx].status = .completed
            tasks[idx].completedAt = Date()
        }
        queueSave()
    }

    func confirmMedication(_ task: BookingTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = .completed
        tasks[idx].completedAt = Date()
        queueSave()
    }

    func markUnable(_ task: BookingTask, reason: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = .unableToComplete
        tasks[idx].unableReason = reason
        queueSave()
    }

    func updateNote(for task: BookingTask, note: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].note = note
        queueSave()
    }

    private func queueSave() {
        syncState = .syncing
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { self?.syncState = .synced }
        }
    }

    func save() async {
        isSaving = true
        syncState = .syncing
        try? await Task.sleep(nanoseconds: 600_000_000)
        syncState = .synced
        isSaving = false
    }
}

struct TaskChecklistView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    let booking: Booking
    @State private var viewModel: TaskChecklistViewModel

    init(booking: Booking) {
        self.booking = booking
        self._viewModel = State(initialValue: TaskChecklistViewModel(booking: booking))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.md) {
                    progressHeader
                    ForEach($viewModel.tasks) { $task in
                        TaskRow(task: $task,
                                onToggle: { viewModel.toggle(task) },
                                onConfirmMedication: { viewModel.confirmMedication(task) },
                                onMarkUnable: { viewModel.taskForDeclineReason = task },
                                onNoteChanged: { viewModel.updateNote(for: task, note: $0) })
                        .padding(.horizontal, CuraSpacing.md)
                    }
                    saveButton
                        .padding(.horizontal, CuraSpacing.md)
                        .padding(.bottom, CuraSpacing.xl)
                }
                .padding(.top, CuraSpacing.md)
            }
            .background(Color.curaBackground)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStateChip(state: viewModel.syncState)
                }
            }
            .sheet(item: $viewModel.taskForDeclineReason) { task in
                UnableReasonSheet(taskTitle: task.title, reason: $viewModel.declineReasonText) {
                    viewModel.markUnable(task, reason: viewModel.declineReasonText)
                    viewModel.declineReasonText = ""
                }
            }
        }
    }

    private var progressHeader: some View {
        CareCard {
            VStack(spacing: CuraSpacing.sm) {
                HStack {
                    Text("\(viewModel.completedCount) of \(viewModel.totalCount) tasks completed")
                        .font(.curaHeadline)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.curaBody).foregroundStyle(.secondary)
                }
                ProgressView(value: viewModel.progress).tint(.curaSuccess)
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    private var saveButton: some View {
        PrimaryButton("Save All", icon: "checkmark.circle.fill", isLoading: viewModel.isSaving) {
            Task { await viewModel.save() }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    @Binding var task: BookingTask
    let onToggle: () -> Void
    let onConfirmMedication: () -> Void
    let onMarkUnable: () -> Void
    let onNoteChanged: (String) -> Void

    @State private var isExpanded: Bool = false
    @State private var showNote: Bool = false
    @State private var noteText: String = ""

    var body: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack(alignment: .top, spacing: CuraSpacing.sm) {
                    completionToggle
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(task.title)
                                .font(.curaBody).fontWeight(.medium)
                                .strikethrough(task.status == .completed, color: .secondary)
                            Spacer()
                            StatusBadge(task.status.rawValue, color: task.status.badgeColor)
                        }
                        if let t = task.scheduledTime {
                            Text(t.formatted(date: .omitted, time: .shortened))
                                .font(.curaCaption).foregroundStyle(.secondary)
                        }
                    }
                }

                if task.isMedicationRelated {
                    medicationBanner
                }

                if let instruction = task.instruction, !instruction.isEmpty {
                    Button(action: { withAnimation(.spring(response: 0.25)) { isExpanded.toggle() } }) {
                        HStack {
                            Text(isExpanded ? "Hide instructions" : "Show instructions")
                                .font(.curaCaption).foregroundStyle(.curaBlue)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10)).foregroundStyle(.curaBlue)
                        }
                    }
                    .frame(minHeight: 32)

                    if isExpanded {
                        Text(instruction)
                            .font(.curaBody).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(CuraSpacing.sm)
                            .background(Color.curaBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                if task.status == .unableToComplete, let reason = task.unableReason, !reason.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle").foregroundStyle(.curaWarning)
                        Text(reason).font(.curaCaption).foregroundStyle(.secondary)
                    }
                }

                if task.status == .completed {
                    HStack(spacing: CuraSpacing.sm) {
                        Image(systemName: "note.text").foregroundStyle(.secondary).font(.system(size: 14))
                        if showNote {
                            TextField("Optional note…", text: $noteText, axis: .vertical)
                                .font(.curaBody)
                                .onSubmit { onNoteChanged(noteText) }
                        } else {
                            Button(action: { showNote = true }) {
                                Text(task.note?.isEmpty == false ? task.note! : "Add note")
                                    .font(.curaCaption).foregroundStyle(.curaBlue)
                            }
                        }
                    }
                    .frame(minHeight: 36)
                }

                if task.status != .completed && task.status != .unableToComplete {
                    Button(role: .destructive, action: onMarkUnable) {
                        Label("Unable to complete", systemImage: "xmark.circle")
                            .font(.curaCaption).foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 36)
                }
            }
        }
        .onAppear { noteText = task.note ?? "" }
    }

    private var completionToggle: some View {
        Group {
            if task.isMedicationRelated {
                Button(action: onConfirmMedication) {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 28))
                        .foregroundStyle(task.status == .completed ? .curaSuccess : .curaWarning)
                }
                .frame(width: 44, height: 44)
            } else {
                Button(action: onToggle) {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(task.status == .completed ? .curaSuccess : .secondary)
                }
                .frame(width: 44, height: 44)
            }
        }
    }

    private var medicationBanner: some View {
        HStack(spacing: CuraSpacing.sm) {
            Image(systemName: "pill.fill").foregroundStyle(.curaWarning).font(.system(size: 14))
            Text("Medication reminder only — not confirmed as administered")
                .font(.curaCaption).foregroundStyle(.curaWarning)
        }
        .padding(.horizontal, CuraSpacing.sm).padding(.vertical, 6)
        .background(Color.curaWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Unable Reason Sheet

private struct UnableReasonSheet: View {
    let taskTitle: String
    @Binding var reason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: CuraSpacing.lg) {
                Text("Why was "\(taskTitle)" not completed?")
                    .font(.curaHeadline)
                    .multilineTextAlignment(.center)
                    .padding(.top, CuraSpacing.lg)

                TextEditor(text: $reason)
                    .font(.curaBody)
                    .frame(minHeight: 100, maxHeight: 180)
                    .padding(CuraSpacing.sm)
                    .background(Color.curaCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                PrimaryButton("Save & Continue", color: .curaWarning) {
                    onConfirm()
                    dismiss()
                }
                Spacer()
            }
            .padding(CuraSpacing.md)
            .navigationTitle("Unable to Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TaskChecklistView(booking: SampleData.activeBooking)
        .environment(ServiceContainer())
        .environment(AppSession())
}
