import SwiftUI
import Observation

struct MobilityLogView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    var log: DailyCareLog
    @State private var showFallSheet: Bool = false
    @State private var showVoiceNote: Bool = false
    @State private var isSaving: Bool = false
    @Environment(\.dismiss) private var dismiss

    private func ensureMobility() {
        if log.mobilityLog == nil {
            log.mobilityLog = MobilityLog(
                walkingAids: [], fallEvents: [], recordedAt: Date(), certainty: .directObservation)
        }
    }

    private func toggleWalkingAid(_ aid: WalkingAid) {
        ensureMobility()
        if log.mobilityLog?.walkingAids.contains(aid) == true {
            log.mobilityLog?.walkingAids.removeAll { $0 == aid }
        } else {
            log.mobilityLog?.walkingAids.append(aid)
        }
    }

    var hasUrgentFall: Bool {
        log.mobilityLog?.fallEvents.contains { $0.type == .fallWithPossibleInjury } == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.lg) {
                    if hasUrgentFall {
                        UrgentBannerView(message: "Fall with possible injury will be reported as urgent to the family.")
                    }
                    overallSection
                    walkingSection
                    steadinessSection
                    fallsSection
                    movementPainSection
                    VoiceNoteButton { showVoiceNote = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    saveButton
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Mobility")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFallSheet) {
                AddFallEventSheet { event in
                    ensureMobility()
                    log.mobilityLog?.fallEvents.append(event)
                }
            }
            .sheet(isPresented: $showVoiceNote) {
                VoiceUpdateView()
            }
        }
    }

    // MARK: - Overall

    private var overallSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Overall", subtitle: "How much help did they need today?")
                VStack(spacing: CuraSpacing.sm) {
                    ForEach(MobilityOverall.allCases, id: \.self) { option in
                        SelectionCard(title: option.rawValue,
                                      isSelected: log.mobilityLog?.overall == option) {
                            ensureMobility()
                            log.mobilityLog?.overall = option
                        }
                    }
                }
            }
        }
    }

    // MARK: - Walking

    private var walkingSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Walking today", subtitle: "Select all that apply")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(WalkingAid.allCases, id: \.self) { aid in
                        ChipButton(title: aid.rawValue,
                                   isSelected: log.mobilityLog?.walkingAids.contains(aid) == true) {
                            toggleWalkingAid(aid)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Steadiness

    private var steadinessSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Steadiness")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(Steadiness.allCases, id: \.self) { s in
                        ChipButton(title: s.rawValue,
                                   isSelected: log.mobilityLog?.steadiness == s) {
                            ensureMobility()
                            log.mobilityLog?.steadiness = s
                        }
                    }
                }
            }
        }
    }

    // MARK: - Falls

    private var fallsSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    SectionHeader("Falls & Near-Falls")
                    Spacer()
                    Button(action: { showFallSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22)).foregroundStyle(.curaBlue)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                if let events = log.mobilityLog?.fallEvents, !events.isEmpty {
                    ForEach(events) { event in
                        HStack(spacing: CuraSpacing.sm) {
                            Image(systemName: event.type == .fallWithPossibleInjury ? "exclamationmark.triangle.fill" : "figure.fall")
                                .foregroundStyle(event.type == .fallWithPossibleInjury ? .curaUrgent : .curaWarning)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type.rawValue).font(.curaBody)
                                Text(event.time.formatted(date: .omitted, time: .shortened))
                                    .font(.curaCaption).foregroundStyle(.secondary)
                                if !event.note.isEmpty {
                                    Text(event.note).font(.curaCaption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                } else {
                    Text("No falls or near-falls recorded")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Movement Pain

    private var movementPainSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Movement pain or discomfort?")
                HStack(spacing: CuraSpacing.sm) {
                    ForEach([(true, "Yes"), (false, "No")], id: \.0) { val, label in
                        ChipButton(title: label, isSelected: log.mobilityLog?.movementPain == val,
                                   selectedColor: val ? .curaWarning : .curaSuccess) {
                            ensureMobility()
                            log.mobilityLog?.movementPain = val
                        }
                    }
                    ChipButton(title: "Unable to assess", isSelected: log.mobilityLog?.movementPain == nil && log.mobilityLog != nil) {
                        ensureMobility()
                        log.mobilityLog?.movementPain = nil
                    }
                }
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton("Save Mobility Log", icon: "checkmark.circle.fill", isLoading: isSaving) {
            isSaving = true
            log.mobilityLog?.recordedAt = Date()
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

// MARK: - Add Fall Event Sheet

private struct AddFallEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fallType: FallType = .nearFall
    @State private var time: Date = Date()
    @State private var note: String = ""
    let onAdd: (FallEvent) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: CuraSpacing.lg) {
                CareCard {
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        SectionHeader("Type of incident")
                        VStack(spacing: CuraSpacing.sm) {
                            ForEach(FallType.allCases, id: \.self) { type in
                                SelectionCard(title: type.rawValue, isSelected: fallType == type) {
                                    fallType = type
                                }
                            }
                        }
                        if fallType == .fallWithPossibleInjury {
                            UrgentBannerView(message: "This will be reported as urgent to the family.")
                                .padding(.top, CuraSpacing.xs)
                        }
                    }
                }
                CareCard {
                    HStack {
                        SectionHeader("Time")
                        Spacer()
                        DatePicker("", selection: $time, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        SectionHeader("Note (optional)")
                        TextField("What happened, how it was handled…", text: $note, axis: .vertical)
                            .font(.curaBody).lineLimit(3, reservesSpace: true)
                    }
                }
                PrimaryButton("Add Fall Event", color: fallType == .fallWithPossibleInjury ? .curaUrgent : .curaBlue) {
                    onAdd(FallEvent(type: fallType, time: time, note: note))
                    dismiss()
                }
                Spacer()
            }
            .padding(CuraSpacing.md)
            .navigationTitle("Add Fall Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    MobilityLogView(log: SampleData.emptyCareLog())
        .environment(ServiceContainer())
        .environment(AppSession())
}
