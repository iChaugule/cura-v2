import SwiftUI

struct MoodBehaviorLogView: View {
    @Bindable var log: DailyCareLog
    @State private var selectedMood: MoodState?
    @State private var behaviorEvents: [BehaviorEvent] = []
    @State private var calmingStrategies: [CalmingStrategyRecord] = []
    @State private var severity: BehaviorSeverity?
    @State private var showBehaviorPicker = false
    @State private var showGuidanceCard = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    moodSection
                    behaviorSection
                    if !behaviorEvents.isEmpty {
                        calmingStrategiesSection
                        severitySection
                    }
                    voiceNoteButton
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Mood & Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.textSecondary)
                }
            }
            .sheet(isPresented: $showBehaviorPicker) {
                behaviorPickerSheet
            }
            .onAppear { loadExisting() }
        }
        .overlay(alignment: .bottom) {
            if showGuidanceCard {
                guidanceCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showGuidanceCard)
    }

    // MARK: - Mood Grid

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Predominant mood today")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3), spacing: Spacing.xs) {
                ForEach(MoodState.allCases, id: \.self) { mood in
                    moodCard(mood)
                }
            }
        }
    }

    private func moodCard(_ mood: MoodState) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMood = selectedMood == mood ? nil : mood
            }
            if mood.isDistressed {
                withAnimation { showGuidanceCard = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    withAnimation { showGuidanceCard = false }
                }
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(mood.emoji)
                    .font(.system(size: 32))
                Text(mood.rawValue)
                    .font(.careCaption)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80)
            .padding(Spacing.xs)
            .background(selectedMood == mood ? Color.careAccentBlue.opacity(0.15) : Color.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(selectedMood == mood ? Color.careAccentBlue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(mood.rawValue)
        .accessibilityAddTraits(selectedMood == mood ? .isSelected : [])
    }

    // MARK: - Behavior Events

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Behavior events", action: "Add") {
                showBehaviorPicker = true
            }

            if behaviorEvents.isEmpty {
                CareCard {
                    Text("No behavioral events recorded. Tap + to add one.")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(behaviorEvents) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type.rawValue)
                                    .font(.careBodyMedium)
                                    .foregroundStyle(.textPrimary)
                                Text(event.time, style: .time)
                                    .font(.careCaption)
                                    .foregroundStyle(.textSecondary)
                                if !event.note.isEmpty {
                                    Text(event.note)
                                        .font(.careCaption)
                                        .foregroundStyle(.textSecondary)
                                }
                            }
                            Spacer()
                            Button {
                                behaviorEvents.removeAll { $0.id == event.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.textSecondary)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Remove \(event.type.rawValue) event")
                        }
                        .padding(Spacing.md)
                        .background(Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
            }
        }
    }

    // MARK: - Calming Strategies

    private var calmingStrategiesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "What helped?")
            Text("Which calming strategies were tried? Did they help?")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)

            let strategies = [
                "Offered tea",
                "Played Marathi devotional music",
                "Opened family photo album",
                "Redirected to familiar activity",
                "Spoke calmly and reassured",
                "Gave space and time"
            ]

            VStack(spacing: Spacing.xs) {
                ForEach(strategies, id: \.self) { strategy in
                    strategyRow(strategy)
                }
            }
        }
    }

    private func strategyRow(_ strategy: String) -> some View {
        let record = calmingStrategies.first(where: { $0.strategy == strategy })
        let isSelected = record != nil

        return HStack {
            Button {
                if isSelected {
                    calmingStrategies.removeAll { $0.strategy == strategy }
                } else {
                    calmingStrategies.append(CalmingStrategyRecord(strategy: strategy, didHelp: nil))
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .careAccentBlue : .textSecondary)
                    Text(strategy)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                }
                .padding(Spacing.sm)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel(strategy)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isSelected {
                HStack(spacing: Spacing.xs) {
                    Button {
                        if let i = calmingStrategies.firstIndex(where: { $0.strategy == strategy }) {
                            calmingStrategies[i].didHelp = true
                        }
                    } label: {
                        Text("Helped")
                            .font(.careCaption)
                            .foregroundStyle(record?.didHelp == true ? .white : .carePositive)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(record?.didHelp == true ? Color.carePositive : Color.carePositive.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Strategy helped")

                    Button {
                        if let i = calmingStrategies.firstIndex(where: { $0.strategy == strategy }) {
                            calmingStrategies[i].didHelp = false
                        }
                    } label: {
                        Text("Didn't help")
                            .font(.careCaption)
                            .foregroundStyle(record?.didHelp == false ? .white : .textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 4)
                            .background(record?.didHelp == false ? Color.textSecondary : Color.surfaceDepressed)
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Strategy did not help")
                }
            }
        }
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Severity

    private var severitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Overall severity")
            HStack(spacing: Spacing.sm) {
                ForEach(BehaviorSeverity.allCases, id: \.self) { s in
                    Button {
                        severity = severity == s ? nil : s
                    } label: {
                        Text(s.rawValue)
                            .font(.careBodyMedium)
                            .foregroundStyle(severity == s ? .white : severityColor(s))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(severity == s ? severityColor(s) : severityColor(s).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .accessibilityLabel("\(s.rawValue) severity")
                    .accessibilityAddTraits(severity == s ? .isSelected : [])
                }
            }
        }
    }

    private func severityColor(_ s: BehaviorSeverity) -> Color {
        switch s {
        case .mild: return .carePositive
        case .moderate: return .careAttention
        case .significant: return .careUrgent
        }
    }

    // MARK: - Voice Note

    private var voiceNoteButton: some View {
        Button {
            // Voice note recording
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill").foregroundStyle(.careAccentTeal)
                Text("Add voice note").font(.careBodyMedium).foregroundStyle(.careAccentTeal)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.careAccentTeal.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityLabel("Add voice note about mood and behavior")
    }

    // MARK: - Guidance Card

    private var guidanceCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("From her family", systemImage: "heart.fill")
                    .font(.careCaptionBold)
                    .foregroundStyle(.careAccentTeal)
                Text("Offer tea and sit beside her quietly. Play Marathi devotional music softly. Open the family photo album. Never argue or correct — agree and redirect.")
                    .font(.careBody)
                    .foregroundStyle(.textPrimary)
                Divider()
                Text("These are general caregiving suggestions, not medical advice.")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Button { withAnimation { showGuidanceCard = false } } label: {
                    Text("Dismiss").font(.careCaption).foregroundStyle(.textSecondary)
                }
            }
            .padding(Spacing.md)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: -4)
    }

    // MARK: - Behavior Picker Sheet

    private var behaviorPickerSheet: some View {
        NavigationStack {
            List(BehaviorEventType.allCases, id: \.self) { type in
                Button {
                    behaviorEvents.append(BehaviorEvent(type: type, time: Date()))
                    showBehaviorPicker = false
                } label: {
                    Text(type.rawValue)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                }
                .frame(minHeight: 44)
            }
            .navigationTitle("Select behavior event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBehaviorPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadExisting() {
        if let m = log.moodLog {
            selectedMood = m.predominantMood
            behaviorEvents = m.behaviorEvents
            calmingStrategies = m.calmingStrategiesUsed
            severity = m.severity
        }
    }

    private func save() {
        log.moodLog = MoodLog(
            predominantMood: selectedMood,
            behaviorEvents: behaviorEvents,
            calmingStrategiesUsed: calmingStrategies,
            severity: severity,
            recordedAt: Date()
        )
        dismiss()
    }
}

#Preview {
    MoodBehaviorLogView(log: SampleData.dailyCareLog)
}
