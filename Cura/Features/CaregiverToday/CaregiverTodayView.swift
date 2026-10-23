import SwiftUI
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class CaregiverTodayViewModel {
    var booking: Booking = SampleData.activeBooking
    var lovedOne: LovedOne = SampleData.lovedOne
    var isCheckedIn: Bool = false
    var checkInTime: Date? = nil
    var isCheckingIn: Bool = false
    var showEmergencyAlert: Bool = false
    var showPassport: Bool = false

    var visitTimer: String = "00:00:00"
    private var timerTask: Task<Void, Never>?

    var completedTaskCount: Int { booking.tasks.filter { $0.status == .completed }.count }
    var totalTaskCount: Int { booking.tasks.count }

    func checkIn() async {
        isCheckingIn = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        checkInTime = Date()
        booking.status = .inProgress
        isCheckedIn = true
        isCheckingIn = false
        startTimer()
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let start = self.checkInTime else { return }
                    let elapsed = Int(Date().timeIntervalSince(start))
                    let h = elapsed / 3600, m = (elapsed % 3600) / 60, s = elapsed % 60
                    self.visitTimer = String(format: "%02d:%02d:%02d", h, m, s)
                }
            }
        }
    }

    func openDirections() {
        let addr = lovedOne.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?daddr=\(addr)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View

struct CaregiverTodayView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = CaregiverTodayViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.lg) {
                    if viewModel.isCheckedIn {
                        ActiveVisitSummaryCard(viewModel: viewModel)
                        ActiveActionGrid(viewModel: viewModel)
                    } else {
                        AssignmentCard(viewModel: viewModel)
                        HelpMeFeelSafeCard(passport: viewModel.lovedOne.memoryCarePassport)
                        TaskSummaryCard(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle(viewModel.isCheckedIn ? "Caring for \(viewModel.lovedOne.preferredName)" : "Today's Assignment")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isCheckedIn {
                        EmergencyButton { viewModel.showEmergencyAlert = true }
                    }
                }
            }
            .alert("Emergency", isPresented: $viewModel.showEmergencyAlert) {
                Button("Call 112", role: .destructive) {
                    if let url = URL(string: "tel://112") { UIApplication.shared.open(url) }
                }
                Button("Notify Family", role: .none) {}
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("What do you need?")
            }
        }
    }
}

// MARK: - Assignment Card

private struct AssignmentCard: View {
    @Bindable var viewModel: CaregiverTodayViewModel

    var body: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.lovedOne.preferredName)
                            .font(.curaTitle)
                        Text(viewModel.lovedOne.neighborhood)
                            .font(.curaBody).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(viewModel.booking.visitType, color: .curaTeal)
                }

                Divider()

                HStack(spacing: CuraSpacing.lg) {
                    InfoPill(icon: "clock", label: "Start Time", value: viewModel.booking.startTime.formatted(date: .omitted, time: .shortened))
                    InfoPill(icon: "indianrupeesign.circle", label: "Earnings", value: "₹\(Int(viewModel.booking.estimatedEarnings))")
                    InfoPill(icon: "checklist", label: "Tasks", value: "\(viewModel.totalTaskCount)")
                }

                HStack(spacing: CuraSpacing.sm) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary).font(.curaCaption)
                    Text("Language: \(viewModel.booking.languagePreference.rawValue)")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: CuraSpacing.sm) {
                    Button(action: viewModel.openDirections) {
                        Label("Get Directions", systemImage: "map.fill")
                            .font(.curaHeadline)
                            .foregroundStyle(.curaBlue)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.curaBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    PrimaryButton("Check In", icon: "checkmark.circle.fill", isLoading: viewModel.isCheckingIn) {
                        Task { await viewModel.checkIn() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, CuraSpacing.sm)
    }
}

// MARK: - Help Me Feel Safe Card

private struct HelpMeFeelSafeCard: View {
    let passport: MemoryCarePassport?
    @State private var isExpanded = false

    var body: some View {
        guard let passport else { return AnyView(EmptyView()) }
        return AnyView(
            CareCard {
                VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                        HStack {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundStyle(.curaUrgent)
                                .font(.system(size: 20))
                            Text("Help Me Feel Safe")
                                .font(.curaHeadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary).font(.curaCaption)
                        }
                    }
                    if isExpanded {
                        Text(passport.helpMeFeelSafe)
                            .font(.curaBody)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, CuraSpacing.xs)
                        VStack(alignment: .leading, spacing: CuraSpacing.xs) {
                            ForEach(passport.calmingTechniques, id: \.self) { tip in
                                HStack(alignment: .top, spacing: CuraSpacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.curaSuccess)
                                        .font(.system(size: 14))
                                    Text(tip).font(.curaBody)
                                }
                            }
                        }
                        .padding(.top, CuraSpacing.xs)
                    }
                }
            }
        )
    }
}

// MARK: - Task Summary Card

private struct TaskSummaryCard: View {
    let viewModel: CaregiverTodayViewModel
    var body: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Today's Tasks", subtitle: "\(viewModel.totalTaskCount) tasks scheduled")
                ForEach(viewModel.booking.tasks.prefix(3)) { task in
                    HStack(spacing: CuraSpacing.sm) {
                        Image(systemName: task.isMedicationRelated ? "pill.fill" : "checkmark.circle")
                            .foregroundStyle(task.isMedicationRelated ? .curaWarning : .curaBlue)
                            .font(.system(size: 16))
                        Text(task.title).font(.curaBody)
                        Spacer()
                        if let t = task.scheduledTime {
                            Text(t.formatted(date: .omitted, time: .shortened))
                                .font(.curaCaption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 36)
                }
                if viewModel.totalTaskCount > 3 {
                    Text("+ \(viewModel.totalTaskCount - 3) more tasks")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Active Visit Summary

private struct ActiveVisitSummaryCard: View {
    let viewModel: CaregiverTodayViewModel
    var body: some View {
        CareCard {
            VStack(spacing: CuraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Visit in Progress")
                            .font(.curaCaption).foregroundStyle(.secondary)
                        Text(viewModel.visitTimer)
                            .font(.curaMono).font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.curaBlue)
                    }
                    Spacer()
                    StatusBadge("In Progress", color: .curaWarning)
                }
                ProgressView(value: Double(viewModel.completedTaskCount), total: Double(max(1, viewModel.totalTaskCount)))
                    .tint(.curaSuccess)
                Text("\(viewModel.completedTaskCount) of \(viewModel.totalTaskCount) tasks completed")
                    .font(.curaCaption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Active Action Grid

private struct ActiveActionGrid: View {
    let viewModel: CaregiverTodayViewModel
    var remainingTasks: Int { viewModel.booking.tasks.filter { $0.status == .scheduled }.count }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CuraSpacing.md) {
            NavigationLink(destination: Text("Care Passport").navigationTitle("Care Passport")) {
                ActionGridCard(icon: "person.text.rectangle.fill", label: "View Care Passport", iconColor: .curaTeal, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: TaskChecklistView(booking: viewModel.booking)) {
                ActionGridCard(icon: "checklist", label: "Routine & Tasks",
                               badge: remainingTasks > 0 ? "\(remainingTasks)" : nil, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: DailyCareLogHubView()) {
                ActionGridCard(icon: "list.clipboard.fill", label: "Daily Care Log", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: AddObservationView()) {
                ActionGridCard(icon: "plus.circle.fill", label: "Add Observation", iconColor: .curaTeal, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: VoiceUpdateView()) {
                ActionGridCard(icon: "mic.circle.fill", label: "Voice Update", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: CaregiverMessagingView()) {
                ActionGridCard(icon: "message.fill", label: "Message Family", iconColor: .curaBlue, action: {})
            }.buttonStyle(.plain)

            NavigationLink(destination: ShiftHandoffView(booking: viewModel.booking, lovedOne: viewModel.lovedOne)) {
                ActionGridCard(icon: "arrow.left.arrow.right.circle.fill", label: "Complete Handoff", iconColor: .curaWarning, action: {})
            }.buttonStyle(.plain)

            ActionGridCard(icon: "door.right.hand.open", label: "Check Out", iconColor: .secondary, action: {})
        }
    }
}

// MARK: - Info Pill

private struct InfoPill: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.curaBlue)
            Text(value).font(.curaHeadline)
            Text(label).font(.curaCaption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    CaregiverTodayView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
