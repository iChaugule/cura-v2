import SwiftUI

struct FamilyTabView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var selectedTab: FamilyTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(FamilyTab.home.title, systemImage: FamilyTab.home.icon, value: FamilyTab.home) {
                FamilyHomeView()
            }
            Tab(FamilyTab.timeline.title, systemImage: FamilyTab.timeline.icon, value: FamilyTab.timeline) {
                TimelineView()
            }
            Tab(FamilyTab.findCare.title, systemImage: FamilyTab.findCare.icon, value: FamilyTab.findCare) {
                FindCareView()
            }
            Tab(FamilyTab.messages.title, systemImage: FamilyTab.messages.icon, value: FamilyTab.messages) {
                FamilyMessagingView()
            }
            Tab(FamilyTab.profile.title, systemImage: FamilyTab.profile.icon, value: FamilyTab.profile) {
                FamilySettingsView()
            }
        }
        .tint(.careAccentBlue)
    }
}

// MARK: - Tab Model

enum FamilyTab: Int, CaseIterable {
    case home
    case timeline
    case findCare
    case messages
    case profile

    var title: String {
        switch self {
        case .home:     return "Home"
        case .timeline: return "Timeline"
        case .findCare: return "Find Care"
        case .messages: return "Messages"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house.fill"
        case .timeline: return "clock.fill"
        case .findCare: return "person.2.fill"
        case .messages: return "message.fill"
        case .profile:  return "person.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    FamilyTabView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
