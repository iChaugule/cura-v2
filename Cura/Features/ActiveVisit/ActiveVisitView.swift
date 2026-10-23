import SwiftUI
import Observation

@MainActor
@Observable
final class ActiveVisitViewModel {
    var booking: Booking
    var lovedOne: LovedOne
    var checkInTime: Date
    var visitTimer: String = "00:00:00"
    var showEmergency: Bool = false
    private var timerTask: Task<Void, Never>?

    var remainingTaskCount: Int {
        booking.tasks.filter { $0.status == .scheduled || $0.status == .notConfirmed }.count
    }

    init(booking: Booking = SampleData.activeBooking,
         lovedOne: LovedOne = SampleData.lovedOne,
         checkInTime: Date = Date()) {
        self.booking = booking
        self.lovedOne = lovedOne
        self.checkInTime = checkInTime
        startTimer()
    }

    func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self else { return }
                    let e = Int(Date().timeIntervalSince(self.checkInTime))
                    self.visitTimer = String(format: "%02d:%02d:%02d", e / 3600, (e % 3600) / 60, e % 60)
                }
            }
        }
    }
}

struct ActiveVisitView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = ActiveVisitViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.lg) {
                    headerCard
                    actionGrid
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Caring for \(viewModel.lovedOne.preferredName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EmergencyButton { viewModel.showEmergency = true }
                }
            }
            .alert("Emergency", isPresented: $viewModel.showEmergency) {
                Button("Call 112", role: .destructive) {
                    if let url = URL(string: "tel://112") { UIApplication.shared.open(url) }
                }
                Button("Notify Family Now", role: .none) {}
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select the action you need.")
            }
        }
    }

    private var headerCard: some View {
        CareCard {
            VStack(spacing: CuraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Visit Timer")
                            .font(.curaCaption).foregroundStyle(.secondary)
                        Text(viewModel.visitTimer)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.curaBlue)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        StatusBadge("In Progress", color: .curaWarning)
                        Text("Started \(viewModel.checkInTime.formatted(date: .omitted, time: .shortened))")
                            .font(.curaCaption).foregroundStyle(.secondary)
                    }
                }

                ProgressView(
                    value: Double(viewModel.booking.tasks.filter { $0.status == .completed }.count),
                    total: Double(max(1, viewModel.booking.tasks.count))
                )
                .tint(.curaSuccess)

                HStack {
                    Text("\(viewModel.booking.tasks.filter { $0.status == .completed }.count) of \(viewModel.booking.tasks.count) tasks completed")
                        .font(.curaCaption).foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.remainingTaskCount > 0 {
                        Text("\(viewModel.remainingTaskCount) remaining")
                            .font(.curaCaption).foregroundStyle(.curaWarning).fontWeight(.medium)
                    }
                }
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CuraSpacing.md) {
            NavigationLink(destination: Text("Care Passport coming soon").navigationTitle("Care Passport")) {
                ActionGridCard(icon: "person.text.rectangle.fill", label: "View Care Passport", iconColor: .curaTeal, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: TaskChecklistView(booking: viewModel.booking)) {
                ActionGridCard(icon: "checklist", label: "Routine & Tasks",
                               badge: viewModel.remainingTaskCount > 0 ? "\(viewModel.remainingTaskCount)" : nil,
                               iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: DailyCareLogHubView()) {
                ActionGridCard(icon: "list.clipboard.fill", label: "Daily Care Log", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: AddObservationView()) {
                ActionGridCard(icon: "plus.circle.fill", label: "Add Observation", iconColor: .curaTeal, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: VoiceUpdateView()) {
                ActionGridCard(icon: "mic.circle.fill", label: "Record Voice Update", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: CaregiverMessagingView()) {
                ActionGridCard(icon: "message.fill", label: "Message Family", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: Text("Request Support").navigationTitle("Request Support")) {
                ActionGridCard(icon: "person.badge.plus.fill", label: "Request Support", iconColor: .curaWarning, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: Text("Incident Report").navigationTitle("Report Incident")) {
                ActionGridCard(icon: "exclamationmark.triangle.fill", label: "Report Incident", iconColor: .curaUrgent, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: ShiftHandoffView(booking: viewModel.booking, lovedOne: viewModel.lovedOne)) {
                ActionGridCard(icon: "arrow.left.arrow.right.circle.fill", label: "Complete Handoff", iconColor: .curaWarning, action: {})
            }.buttonStyle(.plain)

            ActionGridCard(icon: "door.right.hand.open", label: "Check Out", iconColor: Color.secondary, action: {})
        }
    }
}

#Preview {
    ActiveVisitView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
