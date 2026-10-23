import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class BaselineProfileViewModel {
    var savedBaseline: BaselineProfile = SampleData.lovedOne.baseline ?? BaselineProfile.default
    var editedBaseline: BaselineProfile = SampleData.lovedOne.baseline ?? BaselineProfile.default
    var isEditing: Bool = false
    var isSaving: Bool = false
    var showSavedConfirmation: Bool = false
    var lovedOne: LovedOne = SampleData.lovedOne

    var hasUnsavedChanges: Bool {
        editedBaseline != savedBaseline
    }

    func startEditing() {
        editedBaseline = savedBaseline
        isEditing = true
    }

    func cancelEditing() {
        editedBaseline = savedBaseline
        isEditing = false
    }

    func saveBaseline(container: ServiceContainer) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await container.caregiverService.saveBaseline(editedBaseline, for: lovedOne.id)
            savedBaseline = editedBaseline
            isEditing = false
            showSavedConfirmation = true
        } catch {
            // TODO: surface error
        }
    }
}

// MARK: - Enum display helpers (types defined in Models.swift)

extension AppetiteRating {
    var color: Color {
        switch self {
        case .good: return .carePositive
        case .fair: return .careAttention
        case .poor: return .careUrgent
        }
    }
}

// MARK: - Main View

struct BaselineProfileView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = BaselineProfileViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isEditing {
                    savedBaselineSection
                } else {
                    editableFormSections
                }
            }
            .navigationTitle("Baseline Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .overlay(alignment: .bottom) {
                if viewModel.isEditing {
                    saveBar
                }
            }
            .overlay {
                if viewModel.showSavedConfirmation {
                    savedConfirmationOverlay
                }
            }
        }
    }

    // MARK: Saved View

    private var savedBaselineSection: some View {
        Group {
            Section {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.careAccentBlue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("What's normal for \(viewModel.lovedOne.name)")
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        Text("Used by Cura to detect changes from her usual patterns")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }

            Section("Sleep") {
                baselineRow("Typical wake time", value: viewModel.savedBaseline.formattedWakeTime)
                baselineRow("Sleep pattern", value: viewModel.savedBaseline.sleepPattern)
            }
            Section("Eating & Drinking") {
                baselineRow("Appetite", value: viewModel.savedBaseline.appetiteRating.rawValue)
                baselineRow("Daily fluid target", value: "\(Int(viewModel.savedBaseline.fluidIntakeTargetMl)) mL")
            }
            Section("Mobility & Communication") {
                baselineRow("Walking ability", value: viewModel.savedBaseline.walkingAbility.rawValue)
                baselineRow("Communication level", value: viewModel.savedBaseline.communicationLevel.rawValue)
            }
            Section("Cognition & Mood") {
                baselineRow("Evening behavior", value: viewModel.savedBaseline.eveningBehavior.rawValue)
                baselineRow("Recognizes family", value: viewModel.savedBaseline.recognitionLevel.rawValue)
                baselineRow("Mood range", value: viewModel.savedBaseline.moodRange.rawValue)
            }
            Section("Continence") {
                baselineRow("Toileting pattern", value: viewModel.savedBaseline.toiletingPattern.rawValue)
            }
        }
    }

    private func baselineRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
            Spacer()
            Text(value)
                .font(.careBodyMedium)
                .foregroundStyle(.careAccentBlue)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: Editable Form

    @ViewBuilder
    private var editableFormSections: some View {
        sleepSection
        eatingSection
        mobilitySection
        cognitionSection
        continenceSection
    }

    private var sleepSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Typical wake time")
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text(viewModel.editedBaseline.formattedWakeTime)
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
                Slider(
                    value: $viewModel.editedBaseline.wakeTimeHour,
                    in: 5...10,
                    step: 0.5
                )
                .tint(.careAccentBlue)
                HStack {
                    Text("5:00 AM").font(.careCaption).foregroundStyle(.textSecondary)
                    Spacer()
                    Text("10:00 AM").font(.careCaption).foregroundStyle(.textSecondary)
                }
            }
            .padding(.vertical, Spacing.xs)
            .accessibilityLabel("Wake time slider. Currently \(viewModel.editedBaseline.formattedWakeTime)")

            Picker("Sleep pattern", selection: $viewModel.editedBaseline.sleepPattern) {
                Text("Sleeps through the night").tag("Sleeps through the night")
                Text("1–2 wake-ups").tag("1–2 wake-ups")
                Text("Frequent wake-ups").tag("Frequent wake-ups")
                Text("Daytime naps only").tag("Daytime naps only")
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label("Sleep", systemImage: "moon.fill")
        }
    }

    private var eatingSection: some View {
        Section {
            Picker("Typical appetite", selection: $viewModel.editedBaseline.appetiteRating) {
                ForEach(AppetiteRating.allCases) { rating in
                    Label(rating.rawValue, systemImage: rating.icon).tag(rating)
                }
            }
            .pickerStyle(.navigationLink)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Daily fluid intake target")
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("\(Int(viewModel.editedBaseline.fluidIntakeTargetMl)) mL")
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
                Slider(
                    value: $viewModel.editedBaseline.fluidIntakeTargetMl,
                    in: 500...2000,
                    step: 50
                )
                .tint(.careAccentTeal)
                HStack {
                    Text("500 mL").font(.careCaption).foregroundStyle(.textSecondary)
                    Spacer()
                    Text("2000 mL").font(.careCaption).foregroundStyle(.textSecondary)
                }
            }
            .padding(.vertical, Spacing.xs)
            .accessibilityLabel("Fluid intake slider. Currently \(Int(viewModel.editedBaseline.fluidIntakeTargetMl)) millilitres")
        } header: {
            Label("Eating & Drinking", systemImage: "fork.knife")
        }
    }

    private var mobilitySection: some View {
        Section {
            Picker("Walking ability", selection: $viewModel.editedBaseline.walkingAbility) {
                ForEach(WalkingAbility.allCases) { ability in
                    Text(ability.rawValue).tag(ability)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Communication level", selection: $viewModel.editedBaseline.communicationLevel) {
                ForEach(CommunicationAbilityLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label("Mobility & Communication", systemImage: "figure.walk")
        }
    }

    private var cognitionSection: some View {
        Section {
            Picker("Evening behavior", selection: $viewModel.editedBaseline.eveningBehavior) {
                ForEach(EveningBehavior.allCases) { behavior in
                    Text(behavior.rawValue).tag(behavior)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Recognition of family", selection: $viewModel.editedBaseline.recognitionLevel) {
                ForEach(RecognitionLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Mood range", selection: $viewModel.editedBaseline.moodRange) {
                ForEach(MoodRangeLabel.allCases) { mood in
                    Text(mood.rawValue).tag(mood)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label("Cognition & Mood", systemImage: "brain.head.profile")
        }
    }

    private var continenceSection: some View {
        Section {
            Picker("Toileting pattern", selection: $viewModel.editedBaseline.toiletingPattern) {
                ForEach(ToiletingPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label("Continence", systemImage: "drop.fill")
        } footer: {
            Text("This baseline helps Cura detect meaningful changes. Update it whenever \(viewModel.lovedOne.name)'s condition changes significantly.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    // MARK: Save Bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Spacing.sm) {
                Button("Cancel") {
                    viewModel.cancelEditing()
                }
                .font(.careBodyMedium)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel("Cancel editing baseline")

                Button {
                    Task { await viewModel.saveBaseline(container: container) }
                } label: {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Baseline")
                                .font(.careBodyMedium)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(.white)
                .background(viewModel.hasUnsavedChanges ? Color.careAccentBlue : Color.careAccentBlue.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                .accessibilityLabel("Save baseline profile")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(.systemBackground))
        }
    }

    // MARK: Saved Confirmation

    private var savedConfirmationOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.carePositive)
                Text("Baseline saved")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color.surfaceCard)
            .clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.bottom, Spacing.xxl)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    viewModel.showSavedConfirmation = false
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.isEditing {
                Button("Edit") {
                    viewModel.startEditing()
                }
                .font(.careBodyMedium)
                .accessibilityLabel("Edit baseline profile")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BaselineProfileView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
