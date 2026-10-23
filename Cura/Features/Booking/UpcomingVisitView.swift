import SwiftUI

// MARK: - Acknowledgement Item

private struct AcknowledgementItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    var acknowledged: Bool
    var acknowledgedAt: Date?
}

// MARK: - UpcomingVisitViewModel

@MainActor
@Observable
final class UpcomingVisitViewModel {
    var booking: Booking
    var caregiver: Caregiver?
    var tasks: [BookingTask]
    var minutesUntilArrival: Int = 20
    var showLastMinuteNote: Bool = false
    var lastMinuteNote: String = ""

    var acknowledgements: [AcknowledgementItem] = [
        AcknowledgementItem(
            icon: "person.text.rectangle.fill",
            title: "Care Passport",
            subtitle: "Family's full care profile",
            acknowledged: true,
            acknowledgedAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date())
        ),
        AcknowledgementItem(
            icon: "checklist",
            title: "Task List",
            subtitle: "Today's care tasks",
            acknowledged: true,
            acknowledgedAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date())
        ),
        AcknowledgementItem(
            icon: "exclamationmark.shield.fill",
            title: "Safety Notes",
            subtitle: "Hazards & fall risk notes",
            acknowledged: false,
            acknowledgedAt: nil
        ),
        AcknowledgementItem(
            icon: "pill.fill",
            title: "Medication Schedule",
            subtitle: "Today's meds & instructions",
            acknowledged: false,
            acknowledgedAt: nil
        ),
    ]

    var allAcknowledged: Bool {
        acknowledgements.allSatisfy(\.acknowledged)
    }

    init() {
        self.booking = SampleData.activeBooking
        self.tasks = SampleData.activeBooking.tasks
        self.caregiver = SampleData.caregivers.first
    }
}

// MARK: - UpcomingVisitView

struct UpcomingVisitView: View {
    @Environment(ServiceContainer.self) private var container
    @State private var viewModel = UpcomingVisitViewModel()
    @State private var showEmergency = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    caregiverArrivalCard
                    taskListCard
                    instructionsSummaryCard
                    acknowledgementsCard
                    actionButtons
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upcoming Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEmergency = true
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.careUrgent)
                    }
                    .accessibilityLabel("Emergency actions")
                }
            }
            .sheet(isPresented: $viewModel.showLastMinuteNote) {
                lastMinuteNoteSheet
            }
            .sheet(isPresented: $showEmergency) {
                EmergencyView()
            }
        }
    }

    // MARK: Caregiver Arrival Card

    private var caregiverArrivalCard: some View {
        CareCard {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.careAccentBlue.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Text(String(viewModel.caregiver?.name.prefix(1) ?? "C"))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.careAccentBlue)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(viewModel.caregiver?.name ?? "Caregiver")
                            .font(.careHeading)
                            .foregroundStyle(.textPrimary)
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "car.fill")
                                .font(.caption)
                                .foregroundStyle(.careAccentTeal)
                            Text("Arriving in ~\(viewModel.minutesUntilArrival) min")
                                .font(.careBody)
                                .foregroundStyle(.careAccentTeal)
                        }
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: Spacing.lg) {
                    visitInfoPill(
                        icon: "clock.fill",
                        label: visitTimeRange,
                        color: .careAccentBlue
                    )
                    visitInfoPill(
                        icon: "star.fill",
                        label: String(format: "%.1f rating", viewModel.caregiver?.rating ?? 4.8),
                        color: .careAttention
                    )
                }
            }
            .padding(Spacing.md)
        }
    }

    private func visitInfoPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var visitTimeRange: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let start = viewModel.booking.startTime
        let end = Calendar.current.date(byAdding: .hour, value: 4, to: start) ?? start
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    // MARK: Task List Card

    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Today's tasks (\(viewModel.tasks.count))")
            CareCard {
                VStack(spacing: 0) {
                    ForEach(viewModel.tasks.indices, id: \.self) { idx in
                        taskRow(viewModel.tasks[idx])
                        if idx < viewModel.tasks.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: BookingTask) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? Color.carePositive : Color.textSecondary)
                .font(.body)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(task.title)
                    .font(.careBody)
                    .foregroundStyle(task.isCompleted ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(task.isCompleted)
                if let notes = task.notes {
                    Text(notes)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Instructions Summary

    private var instructionsSummaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Family instructions")
            CareCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Please follow the care passport for routines. Knock before entering. Use Marathi when possible. Check hydration every hour.")
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(3)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundStyle(.careAccentBlue)
                        Text("Translated from English")
                            .font(.careCaption)
                            .foregroundStyle(.careAccentBlue)
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: Acknowledgements Card

    private var acknowledgementsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Caregiver review status")

            CareCard {
                VStack(spacing: 0) {
                    ForEach(viewModel.acknowledgements.indices, id: \.self) { idx in
                        acknowledgementRow(viewModel.acknowledgements[idx])
                        if idx < viewModel.acknowledgements.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }

            if !viewModel.allAcknowledged {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                    Text("The caregiver hasn't reviewed all items yet. You'll be notified when they do.")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }

    private func acknowledgementRow(_ item: AcknowledgementItem) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(item.acknowledged ? Color.carePositive : Color.textSecondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.title)
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Text(item.subtitle)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            if item.acknowledged, let ts = item.acknowledgedAt {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.carePositive)
                        .font(.body)
                    Text(ts, style: .relative)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            } else {
                Text("Pending")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Message Caregiver") { }

            Button {
                viewModel.showLastMinuteNote = true
            } label: {
                Text("Add Last-Minute Note")
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.careAccentBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            }
        }
    }

    // MARK: Last-Minute Note Sheet

    private var lastMinuteNoteSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                TextEditor(text: $viewModel.lastMinuteNote)
                    .font(.careBody)
                    .frame(minHeight: 120)
                    .padding(Spacing.sm)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                PrimaryButton(title: "Send to Caregiver") {
                    viewModel.showLastMinuteNote = false
                }

                Spacer()
            }
            .padding(Spacing.md)
            .navigationTitle("Last-Minute Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.showLastMinuteNote = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    UpcomingVisitView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
