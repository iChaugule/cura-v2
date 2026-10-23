import SwiftUI

struct CaregiverTabView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var selectedTab: CaregiverTab = .today

    enum CaregiverTab: Hashable {
        case today, schedule, log, messages, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CaregiverTodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(CaregiverTab.today)

            CaregiverScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(CaregiverTab.schedule)

            DailyCareLogHubView()
                .tabItem {
                    Label("Log", systemImage: "list.clipboard.fill")
                }
                .tag(CaregiverTab.log)

            CaregiverMessagingView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(CaregiverTab.messages)

            CaregiverProfileSettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(CaregiverTab.profile)
        }
        .tint(.curaBlue)
    }
}

#Preview {
    CaregiverTabView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
