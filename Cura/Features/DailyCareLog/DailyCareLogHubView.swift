import SwiftUI
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class DailyCareLogViewModel {
    var careLog: DailyCareLog
    var isSaving: Bool = false
    var isSubmitting: Bool = false
    var showContextEventSheet: Bool = false
    var newContextEventType: ContextEventType = .other
    var newContextEventNote: String = ""

    init() {
        self.careLog = SampleData.emptyCareLog()
    }

    enum Domain: String, CaseIterable {
        case mobility = "Mobility"
        case sleep = "Sleep"
        case food = "Food & Meals"
        case hydration = "Hydration"
        case mood = "Mood & Behavior"
        case communication = "Communication & Orientation"
        case toileting = "Toileting"
        case medication = "Medication"
        case pain = "Pain & Distress"
        case vitals = "Vitals"

        var icon: String {
            switch self {
            case .mobility: "figure.walk"
            case .sleep: "moon.zzz.fill"
            case .food: "fork.knife"
            case .hydration: "drop.fill"
            case .mood: "face.smiling.fill"
            case .communication: "bubble.left.and.bubble.right.fill"
            case .toileting: "toilet.fill"
            case .medication: "pill.fill"
            case .pain: "waveform.path.ecg"
            case .vitals: "heart.fill"
            }
        }

        var isRequired: Bool {
            switch self { case .mobility, .sleep, .food, .hydration: true; default: false }
        }
    }

    func status(for domain: Domain) -> DomainStatus {
        switch domain {
        case .mobility:      careLog.mobilityLog != nil ? .recorded : .notStarted
        case .sleep:         careLog.sleepLog != nil ? .recorded : .notStarted
        case .food:          careLog.foodLog != nil ? .recorded : .notStarted
        case .hydration:     careLog.hydrationLog != nil ? .recorded : .notStarted
        case .mood:          careLog.moodLog != nil ? .recorded : .notStarted
        case .communication: careLog.communicationLog != nil ? .recorded : .notStarted
        default: .notStarted
        }
    }

    func summary(for domain: Domain) -> String? {
        switch domain {
        case .mobility:
            guard let m = careLog.mobilityLog else { return nil }
            return m.overall?.rawValue ?? "In progress"
        case .sleep:
            guard let s = careLog.sleepLog else { return nil }
            if let h = s.approximateHours {
                return String(format: "~%.0f hrs · %@", h, s.quality?.rawValue ?? "")
            }
            return s.quality?.rawValue
        case .food:
            guard let f = careLog.foodLog else { return nil }
            let recorded = f.meals.filter { $0.intake != nil }.count
            return "\(recorded) of \(f.meals.count) meals recorded"
        case .hydration:
            guard let h = careLog.hydrationLog else { return nil }
            return "\(h.totalML) mL of \(h.baselineML) mL goal"
        case .mood:
            guard let m = careLog.moodLog else { return nil }
            return m.predominantMood?.rawValue
        case .communication:
            return careLog.communicationLog?.communication?.rawValue
        default:
            return nil
        }
    }

    func sameAsUsual() {
        careLog.fillSameAsUsual()
        careLog.syncState = .syncing
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { self?.careLog.syncState = .synced }
        }
    }

    func addContextEvent() {
        let event = ContextEvent(type: newContextEventType, note: newContextEventNote)
        careLog.contextEvents.append(event)
        newContextEventNote = ""
        showContextEventSheet = false
    }

    func submit() async {
        isSubmitting = true
        careLog.syncState = .syncing
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        careLog.submittedAt = Date()
        careLog.syncState = .synced
        isSubmitting = false
    }
}

enum DomainStatus: String {
    case notStarted = "Not started"
    case inProgress = "In progress"
    case recorded = "Recorded"
    case unableToAssess = "Unable to assess"

    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .inProgress: .curaWarning
        case .recorded: .curaSuccess
        case .unableToAssess: .secondary
        }
    }

    var icon: String {
        switch self {
        case .notStarted: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .recorded: "checkmark.circle.fill"
        case .unableToAssess: "minus.circle"
        }
    }
}

// MARK: - View

struct DailyCareLogHubView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = DailyCareLogViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.md) {
                    progressHeader
                    sameAsUsualButton
                    domainList
                    contextEventsSection
                    submitButton
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Daily Care Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SyncStateChip(state: viewModel.careLog.syncState)
                }
            }
            .sheet(isPresented: $viewModel.showContextEventSheet) {
                ContextEventSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Care Log")
                            .font(.curaTitle)
                        Text(viewModel.careLog.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.curaCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(viewModel.careLog.completedDomainCount) of 6 domains")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(viewModel.careLog.completedDomainCount), total: 6)
                    .tint(.curaSuccess)
            }
        }
    }

    // MARK: - Same As Usual

    private var sameAsUsualButton: some View {
        Button(action: { withAnimation { viewModel.sameAsUsual() } }) {
            HStack(spacing: CuraSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.curaSuccess)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Same as usual")
                        .font(.curaHeadline).foregroundStyle(.primary)
                    Text("Fill all domains with normal observations in one tap")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.curaWarning)
            }
            .padding(CuraSpacing.md)
            .background(Color.curaSuccess.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: CuraSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CuraSpacing.cardRadius, style: .continuous)
                .stroke(Color.curaSuccess.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Domain List

    private var domainList: some View {
        VStack(spacing: CuraSpacing.sm) {
            ForEach(DailyCareLogViewModel.Domain.allCases, id: \.self) { domain in
                DomainRow(domain: domain, status: viewModel.status(for: domain),
                          summary: viewModel.summary(for: domain),
                          careLog: viewModel.careLog)
            }
        }
    }

    // MARK: - Context Events

    private var contextEventsSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    SectionHeader("Context Events",
                                  subtitle: "Medication changes, doctor visits, etc.")
                    Spacer()
                    Button(action: { viewModel.showContextEventSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.curaBlue)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                if viewModel.careLog.contextEvents.isEmpty {
                    Text("No context events — tap + to add one")
                        .font(.curaCaption).foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.careLog.contextEvents) { event in
                        HStack(spacing: CuraSpacing.sm) {
                            Image(systemName: event.type.icon)
                                .foregroundStyle(.curaBlue).font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.type.rawValue).font(.curaBody)
                                if !event.note.isEmpty {
                                    Text(event.note).font(.curaCaption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.curaCaption).foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: CuraSpacing.sm) {
            if !viewModel.careLog.canSubmit {
                Text("Record mobility, sleep, food, and hydration to submit")
                    .font(.curaCaption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(
                viewModel.careLog.submittedAt != nil ? "Resubmit Log" : "Submit Daily Log",
                icon: "paperplane.fill",
                isLoading: viewModel.isSubmitting
            ) {
                Task { await viewModel.submit() }
            }
            .disabled(!viewModel.careLog.canSubmit)
            .opacity(viewModel.careLog.canSubmit ? 1 : 0.5)
        }
    }
}

// MARK: - Domain Row

private struct DomainRow: View {
    let domain: DailyCareLogViewModel.Domain
    let status: DomainStatus
    let summary: String?
    var careLog: DailyCareLog

    var destination: some View {
        switch domain {
        case .mobility:      AnyView(MobilityLogView(log: careLog))
        case .sleep:         AnyView(SleepLogView(log: careLog))
        case .food:          AnyView(FoodLogView(log: careLog))
        case .hydration:     AnyView(HydrationLogView(log: careLog))
        case .mood:          AnyView(MoodBehaviorLogView(log: careLog))
        case .communication: AnyView(CommunicationOrientationLogView(log: careLog))
        default: AnyView(Text("\(domain.rawValue) coming soon").navigationTitle(domain.rawValue))
        }
    }

    var body: some View {
        NavigationLink(destination: destination) {
            CareCard {
                HStack(spacing: CuraSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(status == .recorded ? Color.curaSuccess.opacity(0.12) : Color.curaBlue.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: domain.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(status == .recorded ? .curaSuccess : .curaBlue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(domain.rawValue)
                                .font(.curaBody).fontWeight(.medium)
                            if domain.isRequired {
                                Text("Required")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.curaBlue)
                                    .clipShape(Capsule())
                            }
                        }
                        if let sum = summary {
                            Text(sum).font(.curaCaption).foregroundStyle(.secondary)
                        } else {
                            Text(status.rawValue).font(.curaCaption).foregroundStyle(status.color)
                        }
                    }

                    Spacer()

                    Image(systemName: status.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(status.color)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Event Sheet

private struct ContextEventSheet: View {
    @Bindable var viewModel: DailyCareLogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: CuraSpacing.lg) {
                CareCard {
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        SectionHeader("Event Type")
                        WrapLayout(spacing: CuraSpacing.sm) {
                            ForEach(ContextEventType.allCases, id: \.self) { type in
                                ChipButton(title: type.rawValue, isSelected: viewModel.newContextEventType == type) {
                                    viewModel.newContextEventType = type
                                }
                            }
                        }
                    }
                }
                CareCard {
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        SectionHeader("Note (optional)")
                        TextField("Any additional details…", text: $viewModel.newContextEventNote, axis: .vertical)
                            .font(.curaBody).lineLimit(3, reservesSpace: true)
                    }
                }
                PrimaryButton("Add Event", icon: "plus.circle.fill") {
                    viewModel.addContextEvent()
                }
                Spacer()
            }
            .padding(CuraSpacing.md)
            .navigationTitle("Add Context Event")
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
    DailyCareLogHubView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
