import SwiftUI

// MARK: - Application Status

enum ApplicationStatus: String, CaseIterable, Identifiable {
    case underReview   = "Under Review"
    case moreInfoNeeded = "More Info Needed"
    case approved      = "Approved"
    case rejected      = "Rejected"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .underReview:    return .careAttention
        case .moreInfoNeeded: return .careAccentBlue
        case .approved:       return .carePositive
        case .rejected:       return .careUrgent
        }
    }
}

// MARK: - Mock Application Model

private struct CaregiverApplication: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let submittedDate: Date
    var status: ApplicationStatus
    let experience: String
    let languages: [String]
    let background: String
}

// MARK: - Mock Incident Model

private struct IncidentSummary: Identifiable {
    let id = UUID()
    let date: Date
    let type: String
    var status: String
}

// MARK: - Mock Audit Event

private struct AuditEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let user: String
    let action: String
}

// MARK: - AdminReviewViewModel

@MainActor
@Observable
final class AdminReviewViewModel {
    var applications: [CaregiverApplication] = [
        CaregiverApplication(
            name: "Sunita Patil",
            email: "sunita.patil@email.com",
            submittedDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            status: .underReview,
            experience: "5 years elder care, 2 years dementia support",
            languages: ["Marathi", "Hindi", "English"],
            background: "Certified home health aide. Previously worked with Portea Medical."
        ),
        CaregiverApplication(
            name: "Anjali Sharma",
            email: "anjali.s@mail.com",
            submittedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            status: .moreInfoNeeded,
            experience: "3 years, mainly personal care",
            languages: ["Hindi", "English"],
            background: "Completed NSDC-certified course. References pending."
        ),
        CaregiverApplication(
            name: "Ravi Kumar",
            email: "ravi.k@care.in",
            submittedDate: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
            status: .approved,
            experience: "7 years, specializing in physiotherapy support",
            languages: ["Tamil", "English"],
            background: "BPT degree. 7 years clinical and home care experience."
        ),
    ]

    var incidents: [IncidentSummary] = [
        IncidentSummary(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), type: "Fall", status: "Open"),
        IncidentSummary(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), type: "Medication Error", status: "Under Review"),
        IncidentSummary(date: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(), type: "Property Issue", status: "Resolved"),
    ]

    var auditLog: [AuditEvent] = [
        AuditEvent(timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(), user: "admin@cura.app", action: "Approved caregiver: Ravi Kumar"),
        AuditEvent(timestamp: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(), user: "admin@cura.app", action: "Updated status: Anjali Sharma → More Info Needed"),
        AuditEvent(timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(), user: "system", action: "Incident report filed: Fall (Booking #1042)"),
        AuditEvent(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), user: "admin@cura.app", action: "Application reviewed: Sunita Patil"),
        AuditEvent(timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(), user: "system", action: "New caregiver application received: Sunita Patil"),
        AuditEvent(timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), user: "system", action: "Incident report filed: Medication Error (Booking #1038)"),
    ]

    var selectedApplication: CaregiverApplication? = nil
    var showApplicationSheet: Bool = false

    func updateApplicationStatus(_ application: CaregiverApplication, to status: ApplicationStatus) {
        guard let idx = applications.firstIndex(where: { $0.id == application.id }) else { return }
        applications[idx].status = status
        let event = AuditEvent(
            timestamp: Date(),
            user: "admin@cura.app",
            action: "Updated status: \(application.name) → \(status.rawValue)"
        )
        auditLog.insert(event, at: 0)
    }
}

// MARK: - AdminReviewView

struct AdminReviewView: View {
    @State private var viewModel = AdminReviewViewModel()

    var body: some View {
        Group {
            if AppConfig.isAdminBuild {
                adminContent
            } else {
                notAuthorizedView
            }
        }
    }

    // MARK: Not Authorized

    private var notAuthorizedView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.careAttention)
            Text("Not authorized")
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
            Text("This screen is only accessible on Cura admin builds.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Admin Content

    private var adminContent: some View {
        NavigationStack {
            List {
                caregiverApplicationsSection
                incidentsSection
                auditLogSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Admin Review")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $viewModel.selectedApplication) { application in
                ApplicationDetailSheet(
                    application: application,
                    onUpdateStatus: { status in
                        viewModel.updateApplicationStatus(application, to: status)
                        viewModel.selectedApplication = nil
                    }
                )
            }
        }
    }

    // MARK: Caregiver Applications Section

    private var caregiverApplicationsSection: some View {
        Section {
            ForEach(viewModel.applications) { application in
                applicationRow(application)
            }
        } header: {
            Text("Caregiver Applications (\(viewModel.applications.count))")
        }
    }

    private func applicationRow(_ application: CaregiverApplication) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(application.name)
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Text(application.submittedDate, format: .dateTime.day().month().year())
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            StatusBadge(
                icon: statusIcon(application.status),
                label: application.status.rawValue,
                tier: statusTier(application.status)
            )
            Button("Review") {
                viewModel.selectedApplication = application
            }
            .font(.careCaption.weight(.semibold))
            .foregroundStyle(.careAccentBlue)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.careAccentBlue.opacity(0.10))
            .clipShape(Capsule())
        }
        .padding(.vertical, Spacing.xs)
    }

    private func statusIcon(_ status: ApplicationStatus) -> String {
        switch status {
        case .underReview:    return "clock"
        case .moreInfoNeeded: return "questionmark.circle"
        case .approved:       return "checkmark.circle"
        case .rejected:       return "xmark.circle"
        }
    }

    private func statusTier(_ status: ApplicationStatus) -> AlertTier {
        switch status {
        case .underReview:    return .informational
        case .moreInfoNeeded: return .monitorClosely
        case .approved:       return .informational
        case .rejected:       return .urgent
        }
    }

    // MARK: Incidents Section

    private var incidentsSection: some View {
        Section {
            ForEach(viewModel.incidents) { incident in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(incident.type)
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        Text(incident.date, format: .dateTime.day().month().year().hour().minute())
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    Text(incident.status)
                        .font(.careCaption.weight(.medium))
                        .foregroundStyle(incidentStatusColor(incident.status))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(incidentStatusColor(incident.status).opacity(0.10))
                        .clipShape(Capsule())
                }
                .padding(.vertical, Spacing.xs)
            }
        } header: {
            Text("Incidents (\(viewModel.incidents.count))")
        }
    }

    private func incidentStatusColor(_ status: String) -> Color {
        switch status {
        case "Open":         return .careUrgent
        case "Under Review": return .careAttention
        case "Resolved":     return .carePositive
        default:             return .textSecondary
        }
    }

    // MARK: Audit Log Section

    private var auditLogSection: some View {
        Section {
            ForEach(viewModel.auditLog) { event in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text(event.user)
                            .font(.careCaption.weight(.medium))
                            .foregroundStyle(.careAccentBlue)
                        Spacer()
                        Text(event.timestamp, style: .relative)
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                    Text(event.action)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
                .padding(.vertical, Spacing.xxs)
            }
        } header: {
            Text("Audit Log")
        }
    }
}

// MARK: - Application Detail Sheet

private struct ApplicationDetailSheet: View {
    let application: CaregiverApplication
    let onUpdateStatus: (ApplicationStatus) -> Void
    @State private var selectedStatus: ApplicationStatus
    @Environment(\.dismiss) private var dismiss

    init(application: CaregiverApplication, onUpdateStatus: @escaping (ApplicationStatus) -> Void) {
        self.application = application
        self.onUpdateStatus = onUpdateStatus
        self._selectedStatus = State(initialValue: application.status)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Applicant") {
                    detailRow(label: "Name", value: application.name)
                    detailRow(label: "Email", value: application.email)
                    detailRow(label: "Submitted", value: application.submittedDate.formatted(.dateTime.day().month().year()))
                }

                Section("Experience") {
                    Text(application.experience)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                }

                Section("Languages") {
                    ForEach(application.languages, id: \.self) { lang in
                        Text(lang).font(.careBody)
                    }
                }

                Section("Background") {
                    Text(application.background)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(2)
                }

                Section("Status") {
                    Picker("Application status", selection: $selectedStatus) {
                        ForEach(ApplicationStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, Spacing.xs)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Application Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onUpdateStatus(selectedStatus)
                    }
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentBlue)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.careBody).foregroundStyle(.textSecondary)
            Spacer()
            Text(value).font(.careBodyMedium).foregroundStyle(.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview("Admin View (isAdminBuild = false)") {
    AdminReviewView()
        .environment(AppSession.preview)
        .environment(ServiceContainer.preview)
}
