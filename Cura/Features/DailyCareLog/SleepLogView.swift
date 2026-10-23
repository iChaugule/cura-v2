import SwiftUI
import Observation

struct SleepLogView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    var log: DailyCareLog
    @State private var showVoiceNote = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    private func ensureSleep() {
        if log.sleepLog == nil {
            log.sleepLog = SleepLog(
                nightBehaviors: [], reportedBy: .directObservation, recordedAt: Date())
        }
    }

    private func toggleBehavior(_ b: NightBehavior) {
        ensureSleep()
        if log.sleepLog?.nightBehaviors.contains(b) == true {
            log.sleepLog?.nightBehaviors.removeAll { $0 == b }
        } else {
            log.sleepLog?.nightBehaviors.append(b)
        }
    }

    private var hoursText: String {
        guard let h = log.sleepLog?.approximateHours else { return "" }
        return String(format: "Slept approximately %.1f hours", h)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.lg) {
                    nightSleepSection
                    sleepQualitySection
                    nightBehaviorsSection
                    daytimeSleepSection
                    comparisonSection
                    reportedBySection
                    VoiceNoteButton { showVoiceNote = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    saveButton
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoiceNote) { VoiceUpdateView() }
        }
    }

    // MARK: - Night Sleep Times

    private var nightSleepSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.md) {
                SectionHeader("Night sleep", subtitle: "Approximate times are fine")

                HStack(spacing: CuraSpacing.lg) {
                    VStack(spacing: 4) {
                        Text("Bedtime").font(.curaCaption).foregroundStyle(.secondary)
                        DatePicker("",
                                   selection: Binding(
                                    get: { log.sleepLog?.bedtime ?? defaultBedtime() },
                                    set: { ensureSleep(); log.sleepLog?.bedtime = $0 }),
                                   displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("Wake time").font(.curaCaption).foregroundStyle(.secondary)
                        DatePicker("",
                                   selection: Binding(
                                    get: { log.sleepLog?.wakeTime ?? defaultWakeTime() },
                                    set: { ensureSleep(); log.sleepLog?.wakeTime = $0 }),
                                   displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(height: 100)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity)
                }

                if !hoursText.isEmpty {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.curaBlue)
                        Text(hoursText)
                            .font(.curaBody).foregroundStyle(.curaBlue)
                    }
                    .padding(.vertical, CuraSpacing.xs)
                }
            }
        }
    }

    private func defaultBedtime() -> Date {
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    }
    private func defaultWakeTime() -> Date {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Sleep Quality

    private var sleepQualitySection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Sleep quality")
                VStack(spacing: CuraSpacing.sm) {
                    ForEach(SleepQuality.allCases, id: \.self) { quality in
                        SelectionCard(title: quality.rawValue,
                                      isSelected: log.sleepLog?.quality == quality) {
                            ensureSleep()
                            log.sleepLog?.quality = quality
                        }
                    }
                }
            }
        }
    }

    // MARK: - Night Behaviors

    private var nightBehaviorsSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Night behaviors", subtitle: "Select all that apply")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(NightBehavior.allCases, id: \.self) { behavior in
                        ChipButton(title: behavior.rawValue,
                                   isSelected: log.sleepLog?.nightBehaviors.contains(behavior) == true) {
                            toggleBehavior(behavior)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Daytime Sleep

    private var daytimeSleepSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Daytime sleep")
                VStack(spacing: CuraSpacing.sm) {
                    ForEach(DaytimeSleep.allCases, id: \.self) { option in
                        SelectionCard(title: option.rawValue,
                                      isSelected: log.sleepLog?.daytimeSleep == option) {
                            ensureSleep()
                            log.sleepLog?.daytimeSleep = option
                        }
                    }
                }
            }
        }
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Compared to usual")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(SleepComparison.allCases, id: \.self) { option in
                        ChipButton(title: option.rawValue,
                                   isSelected: log.sleepLog?.comparedToUsual == option) {
                            ensureSleep()
                            log.sleepLog?.comparedToUsual = option
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reported By

    private var reportedBySection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Reported by")
                VStack(spacing: CuraSpacing.sm) {
                    ForEach(ObservationCertainty.allCases, id: \.self) { certainty in
                        SelectionCard(title: certainty.rawValue, height: 48,
                                      isSelected: log.sleepLog?.reportedBy == certainty) {
                            ensureSleep()
                            log.sleepLog?.reportedBy = certainty
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton("Save Sleep Log", icon: "checkmark.circle.fill", isLoading: isSaving) {
            isSaving = true
            log.sleepLog?.recordedAt = Date()
            log.syncState = .syncing
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    log.syncState = .synced
                    isSaving = false
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SleepLogView(log: SampleData.emptyCareLog())
        .environment(ServiceContainer())
        .environment(AppSession())
}
