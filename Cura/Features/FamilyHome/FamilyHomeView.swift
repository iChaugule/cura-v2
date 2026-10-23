import SwiftUI
import Foundation

// MARK: - ViewModel

@MainActor
@Observable
final class FamilyHomeViewModel {
    var lovedOne: LovedOne = SampleData.lovedOne
    var visitStatus: VisitStatus = .checkedIn
    var tasks: [BookingTask] = SampleData.activeBooking.tasks
    var alerts: [ConcernAlert] = SampleData.activeAlerts
    var todayAtAGlance: DailyCareLog = SampleData.dailyCareLog
    var activeBooking: Booking? = SampleData.activeBooking
    var caregivers: [Caregiver] = SampleData.caregivers
    var isLoading: Bool = false
    var error: String? = nil

    var activeCaregiverName: String {
        guard let booking = activeBooking else { return "No caregiver scheduled" }
        return caregivers.first(where: { $0.id == booking.caregiverId })?.name ?? "Caregiver"
    }

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let bookings = try await container.bookingService.upcomingBookings()
            activeBooking = bookings.first
            if let booking = activeBooking {
                visitStatus = booking.status
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Domain chip model

private struct DomainChip: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let trajectory: TrajectoryLabel
}

// MARK: - Main View

struct FamilyHomeView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = FamilyHomeViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showLovedOneSwitcher = false

    private var domainChips: [DomainChip] {
        let log = viewModel.todayAtAGlance
        return [
            DomainChip(id: "sleep",    emoji: "🌙", label: "Sleep",    trajectory: log.sleepTrajectory),
            DomainChip(id: "food",     emoji: "🍽", label: "Food",     trajectory: log.mealTrajectory),
            DomainChip(id: "fluids",   emoji: "💧", label: "Fluids",   trajectory: log.hydrationTrajectory),
            DomainChip(id: "mobility", emoji: "🚶", label: "Mobility", trajectory: log.mobilityTrajectory),
            DomainChip(id: "mood",     emoji: "😊", label: "Mood",     trajectory: log.moodTrajectory),
        ]
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerView
                    careStatusCard
                    todayAtAGlanceStrip
                    latestMessageCard
                    if !viewModel.alerts.isEmpty {
                        alertsSection
                    }
                    primaryActionsSection
                    demoDisclaimerLabel
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await viewModel.load(container: container) }
            .sheet(isPresented: $showLovedOneSwitcher) { lovedOneSwitcherSheet }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .timeline:          TimelineView()
                case .messaging:         FamilyMessagingView()
                case .chatbot:           ChatbotView()
                case .findCare:          FindCareView()
                case .alerts:            ConcernAlertsView()
                case .alert(let alert):  AlertDetailView(alert: alert)
                }
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Good \(timeOfDayGreeting)")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text("\(viewModel.lovedOne.name)'s care today")
                    .font(.careDisplayMedium)
                    .foregroundStyle(.textPrimary)
            }
            Spacer()
            Button {
                showLovedOneSwitcher = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    AvatarCircle(name: viewModel.lovedOne.name, url: viewModel.lovedOne.avatarUrl, size: 44)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.careAccentBlue)
                }
            }
            .accessibilityLabel("Switch loved one. Currently showing \(viewModel.lovedOne.name)")
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: Care Status Card

    private var careStatusCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    visitStatusIcon
                        .font(.title2)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(visitStatusTitle)
                            .font(.careHeading)
                            .foregroundStyle(.textPrimary)
                        Text(visitStatusSubtitle)
                            .font(.careBody)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    StatusBadge(
                        icon: visitStatusBadgeIcon,
                        label: visitStatusBadgeLabel,
                        tier: visitStatusTier
                    )
                }
                Divider()
                HStack(spacing: Spacing.lg) {
                    summaryPill(emoji: "🍽", label: mealSummary)
                    summaryPill(emoji: "💧", label: hydrationSummary)
                    summaryPill(emoji: "😊", label: moodSummary)
                    summaryPill(emoji: "🌙", label: sleepSummary)
                }
            }
            .padding(Spacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Care status: \(visitStatusTitle). \(visitStatusSubtitle)")
    }

    @ViewBuilder
    private var visitStatusIcon: some View {
        switch viewModel.visitStatus {
        case .arriving:         Image(systemName: "car.fill").foregroundStyle(.careAccentBlue)
        case .checkedIn:        Image(systemName: "checkmark.circle.fill").foregroundStyle(.carePositive)
        case .late:             Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.careAttention)
        case .completed:        Image(systemName: "checkmark.seal.fill").foregroundStyle(.carePositive)
        case .cancelled:        Image(systemName: "xmark.circle.fill").foregroundStyle(.careUrgent)
        case .replacementNeeded: Image(systemName: "person.badge.plus.fill").foregroundStyle(.careAttention)
        case .noVisit:          Image(systemName: "calendar.badge.minus").foregroundStyle(.textSecondary)
        }
    }

    private var visitStatusTitle: String {
        switch viewModel.visitStatus {
        case .arriving:          return "\(viewModel.activeCaregiverName) is on the way"
        case .checkedIn:         return "\(viewModel.activeCaregiverName) is with Aaji"
        case .late:              return "\(viewModel.activeCaregiverName) is running late"
        case .completed:         return "Visit completed"
        case .cancelled:         return "Today's visit was cancelled"
        case .replacementNeeded: return "Replacement caregiver needed"
        case .noVisit:           return "No visit scheduled today"
        }
    }

    private var visitStatusSubtitle: String {
        switch viewModel.visitStatus {
        case .arriving:          return "Estimated arrival: \(viewModel.activeBooking?.formattedArrivalTime ?? "soon")"
        case .checkedIn:         return "Checked in at \(viewModel.activeBooking?.formattedCheckInTime ?? "earlier today")"
        case .late:              return "Expected at \(viewModel.activeBooking?.formattedArrivalTime ?? "earlier") — we'll notify you"
        case .completed:         return "Care wrapped up at \(viewModel.activeBooking?.formattedCheckOutTime ?? "today")"
        case .cancelled:         return "Cancellation received. No one is with Aaji."
        case .replacementNeeded: return "Your regular caregiver is unavailable — find a replacement"
        case .noVisit:           return "Add a booking to schedule care"
        }
    }

    private var visitStatusBadgeIcon: String {
        switch viewModel.visitStatus {
        case .arriving:          return "car"
        case .checkedIn:         return "checkmark.circle"
        case .late:              return "clock.badge.exclamationmark"
        case .completed:         return "checkmark.seal"
        case .cancelled:         return "xmark.circle"
        case .replacementNeeded: return "person.badge.plus"
        case .noVisit:           return "calendar.badge.minus"
        }
    }

    private var visitStatusBadgeLabel: String {
        switch viewModel.visitStatus {
        case .arriving:          return "Arriving"
        case .checkedIn:         return "Active"
        case .late:              return "Late"
        case .completed:         return "Done"
        case .cancelled:         return "Cancelled"
        case .replacementNeeded: return "Action needed"
        case .noVisit:           return "No visit"
        }
    }

    private var visitStatusTier: AlertTier {
        switch viewModel.visitStatus {
        case .cancelled, .replacementNeeded: return .urgent
        case .late:                          return .monitorClosely
        default:                             return .informational
        }
    }

    private func summaryPill(emoji: String, label: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(emoji).font(.body)
            Text(label)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var mealSummary: String    { viewModel.todayAtAGlance.mealSummaryShort }
    private var hydrationSummary: String { viewModel.todayAtAGlance.hydrationSummaryShort }
    private var moodSummary: String    { viewModel.todayAtAGlance.moodSummaryShort }
    private var sleepSummary: String   { viewModel.todayAtAGlance.sleepSummaryShort }

    // MARK: Today at a Glance Strip

    private var todayAtAGlanceStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Today at a glance")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(domainChips) { chip in
                        domainChipView(chip)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
            }
            .padding(.horizontal, -Spacing.md)
        }
    }

    private func domainChipView(_ chip: DomainChip) -> some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(trajectoryBackground(chip.trajectory))
                    .frame(width: 64, height: 64)
                Text(chip.emoji)
                    .font(.title2)
            }
            Text(chip.label)
                .font(.careCaption)
                .foregroundStyle(.textPrimary)
            Text(trajectoryLabel(chip.trajectory))
                .font(.careCaption)
                .foregroundStyle(trajectoryColor(chip.trajectory))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chip.label): \(trajectoryLabel(chip.trajectory))")
    }

    private func trajectoryLabel(_ t: TrajectoryLabel) -> String {
        switch t {
        case .steady:          return "Steady"
        case .slightlyChanged: return "Slightly\ndifferent"
        case .notablyChanged:  return "Notably\ndifferent"
        case .needsAttention:  return "Needs\nattention"
        case .notRecorded:     return "Not\nrecorded"
        }
    }

    private func trajectoryBackground(_ t: TrajectoryLabel) -> Color {
        switch t {
        case .steady:          return Color.carePositive.opacity(0.12)
        case .slightlyChanged: return Color.careAttention.opacity(0.12)
        case .notablyChanged:  return Color.careAttention.opacity(0.20)
        case .needsAttention:  return Color.careUrgent.opacity(0.12)
        case .notRecorded:     return Color.surfaceRaised
        }
    }

    private func trajectoryColor(_ t: TrajectoryLabel) -> Color {
        switch t {
        case .steady:          return .carePositive
        case .slightlyChanged: return .careAttention
        case .notablyChanged:  return .careAttention
        case .needsAttention:  return .careUrgent
        case .notRecorded:     return .textSecondary
        }
    }

    // MARK: Latest Message Card

    private var latestMessageCard: some View {
        Button {
            navigationPath.append(HomeDestination.messaging)
        } label: {
            CareCard {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.careAccentBlue)
                        .font(.title3)
                        .frame(width: 36, height: 36)
                    if let lastMessage = SampleData.messages.first {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack {
                                Text(lastMessage.senderName)
                                    .font(.careBodyMedium)
                                    .foregroundStyle(.textPrimary)
                                Spacer()
                                Text(lastMessage.timestamp, style: .relative)
                                    .font(.careCaption)
                                    .foregroundStyle(.textSecondary)
                            }
                            Text(lastMessage.translatedBody ?? lastMessage.body)
                                .font(.careBody)
                                .foregroundStyle(.textSecondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("No messages yet")
                            .font(.careBody)
                            .foregroundStyle(.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.textSecondary)
                }
                .padding(Spacing.md)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Latest message from caregiver. Tap to open messages.")
    }

    // MARK: Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Alerts", action: "See all") {
                navigationPath.append(HomeDestination.alerts)
            }
            VStack(spacing: Spacing.xs) {
                ForEach(viewModel.alerts.prefix(3)) { alert in
                    compactAlertRow(alert)
                }
            }
        }
    }

    private func compactAlertRow(_ alert: ConcernAlert) -> some View {
        Button {
            navigationPath.append(HomeDestination.alert(alert))
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: alertIcon(alert.tier))
                    .foregroundStyle(alertColor(alert.tier))
                    .font(.body.weight(.semibold))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(alert.headline)
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    Text(alert.createdAt, style: .relative)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alert: \(alert.headline). \(alertTierLabel(alert.tier)). Tap for details.")
    }

    private func alertIcon(_ tier: AlertTier) -> String {
        switch tier {
        case .urgent:         return "exclamationmark.circle.fill"
        case .monitorClosely: return "exclamationmark.triangle.fill"
        case .informational:  return "info.circle.fill"
        }
    }

    private func alertColor(_ tier: AlertTier) -> Color {
        switch tier {
        case .urgent:         return .careUrgent
        case .monitorClosely: return .careAttention
        case .informational:  return .careAccentBlue
        }
    }

    private func alertTierLabel(_ tier: AlertTier) -> String {
        switch tier {
        case .urgent:         return "Urgent"
        case .monitorClosely: return "Monitor closely"
        case .informational:  return "Informational"
        }
    }

    // MARK: Primary Actions

    private var primaryActionsSection: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                primaryActionButton(
                    icon: "clock.fill",
                    title: "View Live Timeline",
                    color: .careAccentBlue
                ) { navigationPath.append(HomeDestination.timeline) }
                primaryActionButton(
                    icon: "message.fill",
                    title: "Message Caregiver",
                    color: .careAccentTeal
                ) { navigationPath.append(HomeDestination.messaging) }
            }
            HStack(spacing: Spacing.sm) {
                primaryActionButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Ask About Aaji",
                    color: .careCalm
                ) { navigationPath.append(HomeDestination.chatbot) }
                primaryActionButton(
                    icon: "person.badge.plus.fill",
                    title: "Request Backup Care",
                    color: .careAttention
                ) { navigationPath.append(HomeDestination.findCare) }
            }
        }
    }

    private func primaryActionButton(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                Text(title)
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: Demo Disclaimer

    private var demoDisclaimerLabel: some View {
        Text("Fictional demonstration data")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.sm)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.careAccentBlue)
                .font(.body.weight(.semibold))
        }
    }

    // MARK: Loved One Switcher Sheet

    private var lovedOneSwitcherSheet: some View {
        VStack(spacing: Spacing.lg) {
            Text("Your loved ones")
                .font(.careHeading)
                .padding(.top, Spacing.lg)
            Button {
                showLovedOneSwitcher = false
            } label: {
                HStack(spacing: Spacing.sm) {
                    AvatarCircle(name: viewModel.lovedOne.name, url: viewModel.lovedOne.avatarUrl, size: 44)
                    VStack(alignment: .leading) {
                        Text(viewModel.lovedOne.name).font(.careBodyMedium)
                        Text("Currently viewing").font(.careCaption).foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.carePositive)
                }
                .padding(Spacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .padding(.horizontal, Spacing.md)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .presentationDetents([.medium])
    }

    // MARK: Helpers

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}

// MARK: - Navigation Destinations

enum HomeDestination: Hashable {
    case timeline
    case messaging
    case chatbot
    case findCare
    case alerts
    case alert(ConcernAlert)
}

// MARK: - Supporting Views

private struct AvatarCircle: View {
    let name: String
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.careAccentBlue.opacity(0.2))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView
                }
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
    }

    private var initialsView: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.careAccentBlue)
    }
}

// MARK: - Preview

#Preview {
    FamilyHomeView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
