import SwiftUI
import Observation

// MARK: - ViewModel

@MainActor
@Observable
final class CaregiverScheduleViewModel {
    var bookings: [Booking] = SampleData.upcomingBookings
    var isLoading: Bool = false
    var selectedBooking: Booking? = nil

    func load() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        bookings = SampleData.upcomingBookings
        isLoading = false
    }

    func groupedByWeek() -> [(String, [Booking])] {
        let cal = Calendar.current
        let sorted = bookings.sorted { $0.startTime < $1.startTime }
        var groups: [(String, [Booking])] = []
        var currentWeek: String = ""
        var current: [Booking] = []

        for booking in sorted {
            let week = weekLabel(for: booking.date, cal: cal)
            if week != currentWeek {
                if !current.isEmpty { groups.append((currentWeek, current)) }
                currentWeek = week
                current = [booking]
            } else {
                current.append(booking)
            }
        }
        if !current.isEmpty { groups.append((currentWeek, current)) }
        return groups
    }

    private func weekLabel(for date: Date, cal: Calendar) -> String {
        let now = Date()
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        if days < 7 { return "This Week" }
        return "Next Week"
    }
}

// MARK: - View

struct CaregiverScheduleView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = CaregiverScheduleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Loading schedule…")
                } else if viewModel.bookings.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.plus",
                        title: "No Upcoming Visits",
                        message: "Your upcoming assignments will appear here once confirmed."
                    )
                } else {
                    scheduleList
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.curaBackground)
            .task { await viewModel.load() }
        }
    }

    private var scheduleList: some View {
        ScrollView {
            VStack(spacing: CuraSpacing.lg) {
                ForEach(viewModel.groupedByWeek(), id: \.0) { group in
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        Text(group.0)
                            .font(.curaHeadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, CuraSpacing.md)

                        ForEach(group.1) { booking in
                            VisitCard(booking: booking)
                                .padding(.horizontal, CuraSpacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, CuraSpacing.md)
            .padding(.bottom, CuraSpacing.xl)
        }
    }
}

// MARK: - Visit Card

private struct VisitCard: View {
    let booking: Booking
    @State private var showDetail = false

    private var timeRange: String {
        let start = booking.startTime.formatted(date: .omitted, time: .shortened)
        let end   = booking.endTime.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private var dateString: String {
        booking.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateString)
                            .font(.curaCaption).foregroundStyle(.secondary)
                        Text(booking.lovedOnePreferredName)
                            .font(.curaTitle)
                        Text(booking.lovedOneName)
                            .font(.curaBody).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(booking.status.displayText, color: booking.status.badgeColor)
                }

                Divider()

                HStack(spacing: CuraSpacing.lg) {
                    Label(timeRange, systemImage: "clock")
                        .font(.curaBody)
                    Spacer()
                    Label(booking.neighborhood, systemImage: "location.fill")
                        .font(.curaBody).foregroundStyle(.secondary)
                }

                HStack(spacing: CuraSpacing.sm) {
                    Label(booking.visitType, systemImage: "heart.text.square")
                        .font(.curaCaption).foregroundStyle(.secondary)
                    Spacer()
                    Label("₹\(Int(booking.estimatedEarnings))", systemImage: "indianrupeesign.circle")
                        .font(.curaCaption).foregroundStyle(.curaTeal)
                }

                NavigationLink(destination: VisitDetailView(booking: booking)) {
                    Text("View Details")
                        .font(.curaBody).fontWeight(.medium)
                        .foregroundStyle(.curaBlue)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.curaBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Visit Detail View

private struct VisitDetailView: View {
    let booking: Booking

    var body: some View {
        ScrollView {
            VStack(spacing: CuraSpacing.lg) {
                CareCard {
                    VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                        SectionHeader("Assignment Details")
                        DetailRow(label: "Date", value: booking.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        DetailRow(label: "Time", value: "\(booking.startTime.formatted(date: .omitted, time: .shortened)) – \(booking.endTime.formatted(date: .omitted, time: .shortened))")
                        DetailRow(label: "Visit Type", value: booking.visitType)
                        DetailRow(label: "Location", value: booking.neighborhood)
                        DetailRow(label: "Family Contact", value: booking.familyContactName)
                        DetailRow(label: "Language", value: booking.languagePreference.rawValue)
                        DetailRow(label: "Estimated Earnings", value: "₹\(Int(booking.estimatedEarnings))")
                    }
                }

                if !booking.tasks.isEmpty {
                    CareCard {
                        VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                            SectionHeader("Scheduled Tasks", subtitle: "\(booking.tasks.count) tasks")
                            ForEach(booking.tasks) { task in
                                HStack(spacing: CuraSpacing.sm) {
                                    Image(systemName: task.isMedicationRelated ? "pill.fill" : "checkmark.circle")
                                        .foregroundStyle(task.isMedicationRelated ? .curaWarning : .curaBlue)
                                        .font(.system(size: 16))
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title).font(.curaBody)
                                        if let time = task.scheduledTime {
                                            Text(time.formatted(date: .omitted, time: .shortened))
                                                .font(.curaCaption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                }
            }
            .padding(CuraSpacing.md)
        }
        .background(Color.curaBackground)
        .navigationTitle(booking.lovedOnePreferredName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.curaBody).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.curaBody).fontWeight(.medium)
        }
        .frame(minHeight: 36)
    }
}

// MARK: - Preview

#Preview {
    CaregiverScheduleView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
