import SwiftUI

struct ShiftHandoffView: View {
    @Bindable var log: DailyCareLog
    var outgoingName: String = "Priya"
    var incomingName: String = "Anjali"
    var onSubmit: (() -> Void)?

    @State private var moodSummary: String = ""
    @State private var mealsSummary: String = ""
    @State private var hydrationSummary: String = ""
    @State private var medicationNotes: String = ""
    @State private var mobilityNotes: String = ""
    @State private var behavioralObservations: String = ""
    @State private var calmingStrategiesWorked: String = ""
    @State private var immediateSafetyConcerns: String = ""
    @State private var isUrgentFlag = false
    @State private var remainingTaskTitles: [String] = []
    @State private var submitting = false
    @State private var submitted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if submitted {
                submittedView
            } else {
                formView
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                headerCard
                moodField
                mealsField
                hydrationField
                medicationField
                mobilityField
                behaviorField
                calmingField
                remainingTasksField
                safetyConcernsField
                submitButton
                disclaimerLabel
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.curaBackground)
        .navigationTitle("Shift Handoff")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(.textSecondary)
            }
        }
        .onAppear { prefill() }
    }

    private var headerCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.careAccentTeal)
                    VStack(alignment: .leading) {
                        Text("\(outgoingName) → \(incomingName)")
                            .font(.careHeading)
                            .foregroundStyle(.textPrimary)
                        Text("Handoff for Aaji · \(Date().formatted(date: .abbreviated, time: .omitted))")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Divider()
                Text("This handoff is pre-filled from your Daily Care Log. Review and edit before submitting. The incoming caregiver must acknowledge before beginning their visit.")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
            }
            .padding(Spacing.md)
        }
    }

    private var moodField: some View {
        fieldCard(
            icon: "face.smiling",
            title: "Current mood",
            placeholder: "e.g. Calm and comfortable. Had a brief moment of restlessness around 4:30 PM.",
            text: $moodSummary
        )
    }

    private var mealsField: some View {
        fieldCard(
            icon: "fork.knife",
            title: "Meals summary",
            placeholder: "e.g. Breakfast: ate most. Lunch: about half.",
            text: $mealsSummary
        )
    }

    private var hydrationField: some View {
        fieldCard(
            icon: "drop.fill",
            title: "Hydration summary",
            placeholder: "e.g. Total ~550 mL. Declined fluids twice in the afternoon.",
            text: $hydrationSummary
        )
    }

    private var medicationField: some View {
        fieldCard(
            icon: "pills.fill",
            title: "Medication",
            placeholder: "e.g. Amlodipine reminder was given at 8 AM — not confirmed as taken.",
            text: $medicationNotes
        )
    }

    private var mobilityField: some View {
        fieldCard(
            icon: "figure.walk",
            title: "Mobility",
            placeholder: "e.g. Morning walk completed with walker. Steady. No falls.",
            text: $mobilityNotes
        )
    }

    private var behaviorField: some View {
        fieldCard(
            icon: "brain.head.profile",
            title: "Behavioral observations",
            placeholder: "e.g. Restless around 4:30–5 PM. Asked for her husband twice. Calmed after music.",
            text: $behavioralObservations
        )
    }

    private var calmingField: some View {
        fieldCard(
            icon: "heart.fill",
            title: "Calming strategies that worked",
            placeholder: "e.g. Marathi music and chai helped. Family photo album also helped settle her.",
            text: $calmingStrategiesWorked
        )
    }

    private var remainingTasksField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Tasks remaining")

            let remaining = log.bookingId == SampleData.activeBookingID ?
                SampleData.sampleTasks.filter { $0.status != .completed } : []

            if remaining.isEmpty && remainingTaskTitles.isEmpty {
                CareCard {
                    Text("All tasks completed.")
                        .font(.careBody)
                        .foregroundStyle(.carePositive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(remaining) { task in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(.careAttention)
                            Text(task.title)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text(task.status.rawValue)
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(Spacing.sm)
                        .background(Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
            }
        }
    }

    private var safetyConcernsField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Immediate safety concerns")

            CareCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Toggle(isOn: $isUrgentFlag) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(isUrgentFlag ? .careUrgent : .textSecondary)
                            Text("Flag as urgent for incoming caregiver")
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                        }
                    }
                    .tint(.careUrgent)
                    .frame(minHeight: 44)

                    TextField("Describe any immediate concerns…", text: $immediateSafetyConcerns, axis: .vertical)
                        .font(.careBody)
                        .lineLimit(2...6)
                        .padding(Spacing.sm)
                        .background(Color.surfaceDepressed)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(Spacing.md)
            }
        }
    }

    private var submitButton: some View {
        PrimaryButton(title: submitting ? "Submitting…" : "Submit Handoff", isLoading: submitting) {
            Task { await submit() }
        }
    }

    private var disclaimerLabel: some View {
        Text("Once submitted, the incoming caregiver will be notified and must acknowledge before beginning their visit.")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Submitted View

    private var submittedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.carePositive)
            Text("Handoff submitted")
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
            Text("\(incomingName) has been notified and must acknowledge the handoff before beginning their visit.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
        .navigationTitle("Handoff Complete")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Field Helper

    private func fieldCard(icon: String, title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: icon)
                .font(.careHeading)
                .foregroundStyle(.textPrimary)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.careBody)
                .lineLimit(2...6)
                .padding(Spacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    // MARK: - Actions

    private func prefill() {
        if let m = log.moodLog, let mood = m.predominantMood {
            moodSummary = "Predominant mood: \(mood.rawValue)."
            if !m.calmingStrategiesUsed.isEmpty {
                calmingStrategiesWorked = m.calmingStrategiesUsed
                    .filter { $0.didHelp == true }
                    .map(\.strategy)
                    .joined(separator: ", ")
            }
        }
        if let f = log.foodLog {
            let breakfastIntake = f.meals.first(where: { $0.mealType == .breakfast })?.intake?.rawValue ?? "not recorded"
            let lunchIntake = f.meals.first(where: { $0.mealType == .lunch })?.intake?.rawValue ?? "not recorded"
            mealsSummary = "Breakfast: \(breakfastIntake). Lunch: \(lunchIntake)."
        }
        if let h = log.hydrationLog {
            hydrationSummary = "Total: \(h.totalML) mL. Refusals: \(h.refusalCount)."
        }
        if let m = log.mobilityLog {
            mobilityNotes = m.overall?.rawValue ?? "Mobility not recorded."
        }
    }

    private func submit() async {
        submitting = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        submitting = false
        submitted = true
        onSubmit?()
    }
}

// MARK: - Handoff Acknowledgement

struct HandoffAcknowledgementView: View {
    let handoff: HandoffRecord
    var onAcknowledge: (() -> Void)?
    @State private var acknowledging = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerCard
                    summaryCards
                    if !handoff.immediateSafetyConcerns.isEmpty {
                        urgencyCard
                    }
                    acknowledgementButton
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Incoming Handoff")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("\(handoff.outgoingCaregiverName) → \(handoff.incomingCaregiverName)", systemImage: "arrow.left.arrow.right.circle.fill")
                    .font(.careHeading)
                    .foregroundStyle(.careAccentTeal)
                Text("Review all sections before beginning your visit.")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
            }
            .padding(Spacing.md)
        }
    }

    private var summaryCards: some View {
        VStack(spacing: Spacing.xs) {
            handoffRow(icon: "face.smiling", title: "Mood", text: handoff.moodSummary)
            handoffRow(icon: "fork.knife", title: "Meals", text: handoff.mealsSummary)
            handoffRow(icon: "drop.fill", title: "Hydration", text: handoff.hydrationSummary)
            handoffRow(icon: "pills.fill", title: "Medication", text: handoff.medicationNotes)
            handoffRow(icon: "figure.walk", title: "Mobility", text: handoff.mobilityNotes)
            handoffRow(icon: "brain.head.profile", title: "Behavioral", text: handoff.behavioralObservations)
            handoffRow(icon: "heart.fill", title: "What helped", text: handoff.calmingStrategiesWorked)
        }
    }

    private func handoffRow(icon: String, title: String, text: String) -> some View {
        CareCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(.careAccentBlue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.careCaptionBold).foregroundStyle(.textSecondary)
                    Text(text.isEmpty ? "Not recorded" : text)
                        .font(.careBody)
                        .foregroundStyle(text.isEmpty ? .textSecondary : .textPrimary)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var urgencyCard: some View {
        CareCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.careUrgent)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Immediate safety concerns")
                        .font(.careCaptionBold).foregroundStyle(.careUrgent)
                    Text(handoff.immediateSafetyConcerns)
                        .font(.careBody).foregroundStyle(.textPrimary)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var acknowledgementButton: some View {
        PrimaryButton(title: acknowledging ? "Recording…" : "Acknowledge & Begin Visit", isLoading: acknowledging) {
            Task {
                acknowledging = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                acknowledging = false
                onAcknowledge?()
                dismiss()
            }
        }
    }
}

#Preview("Handoff Form") {
    ShiftHandoffView(log: SampleData.dailyCareLog)
}

#Preview("Acknowledgement") {
    HandoffAcknowledgementView(handoff: HandoffRecord(
        bookingId: SampleData.activeBookingID,
        outgoingCaregiverId: SampleData.caregiverID,
        outgoingCaregiverName: "Priya",
        incomingCaregiverName: "Anjali",
        moodSummary: "Calm in the morning, restless around 4:30 PM.",
        mealsSummary: "Breakfast: mostly ate. Lunch: about half.",
        hydrationSummary: "550 mL total. Declined twice.",
        behavioralObservations: "Asked for Appa twice. Calmed with music.",
        calmingStrategiesWorked: "Marathi music, family photo album."
    ))
}
