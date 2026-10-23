import SwiftUI

struct CommunicationOrientationLogView: View {
    @Bindable var log: DailyCareLog
    @State private var selectedCommunication: CommunicationLevel?
    @State private var selectedOrientation: Set<OrientationObservation> = []
    @State private var conversationLength: ConversationLength?
    @State private var repeatedQuestionCount: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    communicationSection
                    orientationSection
                    conversationLengthSection
                    if selectedOrientation.contains(.repeatedSameQuestion) {
                        repeatedQuestionCountSection
                    }
                    voiceNoteButton
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Communication & Orientation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.textSecondary)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    // MARK: - Communication Level

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Communication today")

            VStack(spacing: Spacing.xs) {
                ForEach(CommunicationLevel.allCases, id: \.self) { level in
                    Button {
                        selectedCommunication = selectedCommunication == level ? nil : level
                    } label: {
                        HStack {
                            Image(systemName: selectedCommunication == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCommunication == level ? .careAccentBlue : .textSecondary)
                            Text(level.rawValue)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .frame(minHeight: 52)
                        .background(selectedCommunication == level ? Color.careAccentBlue.opacity(0.08) : Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(level.rawValue)
                    .accessibilityAddTraits(selectedCommunication == level ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Orientation

    private var orientationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Orientation (select all that apply)")

            VStack(spacing: Spacing.xs) {
                ForEach(OrientationObservation.allCases, id: \.self) { obs in
                    Button {
                        if selectedOrientation.contains(obs) {
                            selectedOrientation.remove(obs)
                        } else {
                            selectedOrientation.insert(obs)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedOrientation.contains(obs) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedOrientation.contains(obs) ? .careAccentBlue : .textSecondary)
                            Text(obs.rawValue)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .frame(minHeight: 52)
                        .background(selectedOrientation.contains(obs) ? Color.careAccentBlue.opacity(0.08) : Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(obs.rawValue)
                    .accessibilityAddTraits(selectedOrientation.contains(obs) ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Conversation Length

    private var conversationLengthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Conversation length compared to usual")

            HStack(spacing: Spacing.xs) {
                ForEach(ConversationLength.allCases, id: \.self) { length in
                    Button {
                        conversationLength = conversationLength == length ? nil : length
                    } label: {
                        Text(length.rawValue)
                            .font(.careCaption)
                            .foregroundStyle(conversationLength == length ? .white : .textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .padding(.horizontal, Spacing.xs)
                            .background(conversationLength == length ? Color.careAccentBlue : Color.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .accessibilityLabel(length.rawValue)
                    .accessibilityAddTraits(conversationLength == length ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Repeated Question Count

    private var repeatedQuestionCountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Approximate number of repeated questions")

            CareCard {
                HStack {
                    Text("Repeated the same question approximately")
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Stepper(value: Binding(
                        get: { repeatedQuestionCount ?? 0 },
                        set: { repeatedQuestionCount = $0 }
                    ), in: 0...50) {
                        Text("\(repeatedQuestionCount ?? 0) times")
                            .font(.careBodyMedium)
                            .foregroundStyle(.careAccentBlue)
                    }
                    .frame(minHeight: 44)
                }
                .padding(Spacing.md)
            }
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
        .accessibilityLabel("Add voice note about communication and orientation")
    }

    // MARK: - Actions

    private func loadExisting() {
        if let c = log.communicationLog {
            selectedCommunication = c.communication
            selectedOrientation = Set(c.orientationObservations)
            conversationLength = c.conversationLength
            repeatedQuestionCount = c.repeatedQuestionCount
        }
    }

    private func save() {
        log.communicationLog = CommunicationOrientationLog(
            communication: selectedCommunication,
            orientationObservations: Array(selectedOrientation),
            conversationLength: conversationLength,
            repeatedQuestionCount: repeatedQuestionCount,
            recordedAt: Date()
        )
        dismiss()
    }
}

#Preview {
    CommunicationOrientationLogView(log: SampleData.dailyCareLog)
}
