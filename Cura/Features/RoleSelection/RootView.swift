import SwiftUI

// MARK: - RootView

/// The single root view that switches between app states based on AppSession.
/// No tab bar or navigation chrome of its own — just switches child views with animation.
struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if !session.onboardingComplete {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if session.currentUser == nil {
                RoleSelectionView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                authenticatedView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.onboardingComplete)
        .animation(.easeInOut(duration: 0.35), value: session.currentUser?.id)
        .animation(.easeInOut(duration: 0.35), value: session.currentRole)
    }

    @ViewBuilder
    private var authenticatedView: some View {
        switch session.currentRole {
        case .familyMember:
            FamilyTabView()
        case .caregiver:
            CaregiverTabView()
        case .admin:
            AdminReviewView()
        case .none:
            RoleSelectionView()
        }
    }
}

// MARK: - Preview

#Preview("Not Onboarded") {
    RootView()
        .environment(AppSession.notOnboarded)
        .environment(ServiceContainer.preview)
}

#Preview("Onboarded — No Sign-In") {
    RootView()
        .environment(AppSession.onboardedSignedOut)
        .environment(ServiceContainer.preview)
}

#Preview("Signed In — Family") {
    RootView()
        .environment(AppSession.preview)
        .environment(ServiceContainer.preview)
}
