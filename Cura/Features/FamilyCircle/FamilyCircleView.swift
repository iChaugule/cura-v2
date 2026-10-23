import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class FamilyCircleViewModel {
    var members: [FamilyCircleMember] = FamilyCircleMember.sampleMembers
    var showInviteSheet: Bool = false
    var selectedMember: FamilyCircleMember? = nil
    var isLoading: Bool = false

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rawUsers = try await container.caregiverService.familyCircleMembers()
            members = rawUsers.map { FamilyCircleMember(from: $0) }
        } catch { }
    }

    func updatePermissions(for member: FamilyCircleMember, container: ServiceContainer) async {
        do {
            try await container.caregiverService.updateMemberPermissions(memberId: member.id)
        } catch { }
    }
}

// MARK: - FamilyCircleMember model

struct FamilyCircleMember: Identifiable {
    var id: String
    var name: String
    var email: String
    var roleBadge: FamilyRole
    var lastActive: Date
    var avatarUrl: URL?
    var activityLog: [String]
    var permissions: MemberPermissions

    static let sampleMembers: [FamilyCircleMember] = [
        FamilyCircleMember(
            id: "m1",
            name: "Sunita Deshpande",
            email: "sunita@example.com",
            roleBadge: .careOrganizer,
            lastActive: Date(),
            avatarUrl: nil,
            activityLog: ["Added booking on Aug 5", "Viewed passport on Aug 3"],
            permissions: MemberPermissions()
        ),
        FamilyCircleMember(
            id: "m2",
            name: "Ramesh Deshpande",
            email: "ramesh@example.com",
            roleBadge: .familyMember,
            lastActive: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
            avatarUrl: nil,
            activityLog: ["Acknowledged alert on Aug 4"],
            permissions: MemberPermissions(
                viewPassport: true, editInstructions: false, bookCaregivers: false,
                cancelVisits: false, managePayments: false, viewTimeline: true,
                receiveAlerts: true, messageCaregivers: false, inviteOthers: false
            )
        ),
        FamilyCircleMember(
            id: "m3",
            name: "Ananya Deshpande",
            email: "ananya@example.com",
            roleBadge: .bookingManager,
            lastActive: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            avatarUrl: nil,
            activityLog: ["Booked caregiver on Aug 2", "Cancelled visit on Jul 28"],
            permissions: MemberPermissions(
                viewPassport: true, editInstructions: false, bookCaregivers: true,
                cancelVisits: true, managePayments: false, viewTimeline: true,
                receiveAlerts: true, messageCaregivers: true, inviteOthers: false
            )
        ),
    ]

    init(id: String, name: String, email: String, roleBadge: FamilyRole, lastActive: Date, avatarUrl: URL?, activityLog: [String], permissions: MemberPermissions) {
        self.id = id; self.name = name; self.email = email; self.roleBadge = roleBadge
        self.lastActive = lastActive; self.avatarUrl = avatarUrl; self.activityLog = activityLog
        self.permissions = permissions
    }

    init(from user: User) {
        id = user.id.uuidString; name = user.displayName; email = user.email
        roleBadge = .familyMember; lastActive = Date()
        avatarUrl = nil; activityLog = []; permissions = MemberPermissions()
    }
}

struct MemberPermissions: Equatable {
    var viewPassport: Bool       = true
    var editInstructions: Bool   = false
    var bookCaregivers: Bool     = false
    var cancelVisits: Bool       = false
    var managePayments: Bool     = false
    var viewTimeline: Bool       = true
    var receiveAlerts: Bool      = true
    var messageCaregivers: Bool  = false
    var inviteOthers: Bool       = false
}

enum FamilyRole: String, CaseIterable, Identifiable {
    case careOrganizer = "Care Organizer"
    case bookingManager = "Booking Manager"
    case familyMember   = "Family Member"
    case viewOnly       = "View Only"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .careOrganizer:  return "star.circle.fill"
        case .bookingManager: return "calendar.circle.fill"
        case .familyMember:   return "person.circle.fill"
        case .viewOnly:       return "eye.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .careOrganizer:  return .careAccentBlue
        case .bookingManager: return .careAccentTeal
        case .familyMember:   return .careCalm
        case .viewOnly:       return .textSecondary
        }
    }
}

// MARK: - Main View

struct FamilyCircleView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = FamilyCircleViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    headerBanner
                    ForEach(viewModel.members) { member in
                        memberRow(member)
                    }
                    inviteButton
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Family Circle")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load(container: container) }
            .sheet(isPresented: $viewModel.showInviteSheet) { inviteSheet }
            .sheet(item: $viewModel.selectedMember) { member in
                MemberDetailSheet(member: member) { updated in
                    if let idx = viewModel.members.firstIndex(where: { $0.id == updated.id }) {
                        viewModel.members[idx] = updated
                        Task { await viewModel.updatePermissions(for: updated, container: container) }
                    }
                    viewModel.selectedMember = nil
                }
            }
        }
    }

    // MARK: Header Banner

    private var headerBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "person.3.fill")
                .foregroundStyle(.careAccentBlue)
                .font(.title3)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(viewModel.members.count) people in this circle")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Text("All members can view \(SampleData.lovedOne.name)'s daily updates")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.careAccentBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: Member Row

    private func memberRow(_ member: FamilyCircleMember) -> some View {
        Button {
            viewModel.selectedMember = member
        } label: {
            HStack(spacing: Spacing.sm) {
                memberAvatar(member)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(member.name)
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: member.roleBadge.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(member.roleBadge.color)
                        Text(member.roleBadge.rawValue)
                            .font(.careCaption)
                            .foregroundStyle(member.roleBadge.color)
                    }
                    Text("Active \(member.lastActive, style: .relative)")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 72)
        .accessibilityLabel("\(member.name), \(member.roleBadge.rawValue). Last active \(member.lastActive, style: .relative). Tap to manage.")
    }

    private func memberAvatar(_ member: FamilyCircleMember) -> some View {
        ZStack {
            Circle().fill(member.roleBadge.color.opacity(0.2))
            if let url = member.avatarUrl {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                    Text(String(member.name.prefix(1)))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(member.roleBadge.color)
                }
                .clipShape(Circle())
            } else {
                Text(String(member.name.prefix(1)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(member.roleBadge.color)
            }
        }
        .frame(width: 52, height: 52)
    }

    // MARK: Invite Button

    private var inviteButton: some View {
        Button {
            viewModel.showInviteSheet = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.careAccentBlue)
                Text("Invite a family member")
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentBlue)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(Spacing.md)
            .background(Color.careAccentBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.careAccentBlue.opacity(0.2), lineWidth: 1)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite a family member to the care circle")
    }

    // MARK: Invite Sheet

    private var inviteSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: .constant(""))
                    TextField("Email address", text: .constant(""))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                Section("Role") {
                    ForEach(FamilyRole.allCases) { role in
                        HStack {
                            Label(role.rawValue, systemImage: role.icon)
                                .foregroundStyle(role.color)
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showInviteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send invite") { viewModel.showInviteSheet = false }
                        .font(.careBodyMedium)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Member Detail Sheet

struct MemberDetailSheet: View {
    @State var member: FamilyCircleMember
    let onSave: (FamilyCircleMember) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    memberHeaderRow
                }
                Section("Role") {
                    Picker("Role", selection: $member.roleBadge) {
                        ForEach(FamilyRole.allCases) { role in
                            Label(role.rawValue, systemImage: role.icon).tag(role)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Permissions") {
                    permissionToggle("View passport",         isOn: $member.permissions.viewPassport)
                    permissionToggle("Edit care instructions", isOn: $member.permissions.editInstructions)
                    permissionToggle("Book caregivers",        isOn: $member.permissions.bookCaregivers)
                    permissionToggle("Cancel visits",          isOn: $member.permissions.cancelVisits)
                    permissionToggle("Manage payments",        isOn: $member.permissions.managePayments)
                    permissionToggle("View timeline",          isOn: $member.permissions.viewTimeline)
                    permissionToggle("Receive alerts",         isOn: $member.permissions.receiveAlerts)
                    permissionToggle("Message caregivers",     isOn: $member.permissions.messageCaregivers)
                    permissionToggle("Invite others",          isOn: $member.permissions.inviteOthers)
                }
                Section("Activity") {
                    ForEach(member.activityLog, id: \.self) { activity in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.textSecondary)
                                .font(.caption)
                            Text(activity)
                                .font(.careBody)
                                .foregroundStyle(.textSecondary)
                        }
                        .frame(minHeight: 36)
                    }
                }
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(member) }
                        .font(.careBodyMedium)
                        .accessibilityLabel("Save permission changes for \(member.name)")
                }
            }
        }
    }

    private var memberHeaderRow: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle().fill(member.roleBadge.color.opacity(0.2))
                Text(String(member.name.prefix(1)))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(member.roleBadge.color)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(member.name).font(.careBodyMedium)
                Text(member.email).font(.careCaption).foregroundStyle(.textSecondary)
            }
        }
        .frame(minHeight: 60)
    }

    private func permissionToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.careBody)
            .tint(.careAccentBlue)
            .frame(minHeight: 44)
            .accessibilityLabel("\(label): \(isOn.wrappedValue ? "Allowed" : "Not allowed"). Tap to toggle.")
    }
}

// MARK: - Preview

#Preview {
    FamilyCircleView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
