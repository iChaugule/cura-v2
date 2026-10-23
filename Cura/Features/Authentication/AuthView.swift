import SwiftUI

// MARK: - AuthMode

enum AuthMode {
    case signIn
    case signUp
}

// MARK: - AuthViewModel

@MainActor
@Observable
final class AuthViewModel {
    var mode: AuthMode
    var role: UserRole

    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var termsAccepted: Bool = false

    var isLoading: Bool = false
    var error: String? = nil
    var isAuthenticated: Bool = false
    var authenticatedUser: User? = nil

    init(role: UserRole, intent: AuthIntent) {
        self.role = role
        self.mode = intent == .signIn ? .signIn : .signUp
    }

    var canSubmitSignUp: Bool {
        !email.isEmpty && password.count >= 8 && password == confirmPassword && termsAccepted
    }

    var canSubmitSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }

    func signUp(container: ServiceContainer, session: AppSession) async {
        guard canSubmitSignUp else {
            if !termsAccepted {
                error = "Please accept the Terms of Service to continue."
            } else if password != confirmPassword {
                error = "Passwords do not match."
            } else if password.count < 8 {
                error = "Password must be at least 8 characters."
            }
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let user = try await container.authService.signUp(email: email, password: password, role: role)
            session.signIn(user: user, role: role)
            authenticatedUser = user
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signIn(container: ServiceContainer, session: AppSession) async {
        guard canSubmitSignIn else {
            error = "Please enter your email and password."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let user = try await container.authService.signIn(email: email, password: password)
            session.signIn(user: user, role: role)
            authenticatedUser = user
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - AuthView

struct AuthView: View {
    let role: UserRole
    let intent: AuthIntent

    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel: AuthViewModel

    init(role: UserRole, intent: AuthIntent = .signUp) {
        self.role = role
        self.intent = intent
        self._viewModel = State(initialValue: AuthViewModel(role: role, intent: intent))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                formSection
                if viewModel.error != nil {
                    errorCard
                }
                if role == .caregiver && viewModel.mode == .signUp {
                    caregiverInfoCard
                }
                Spacer(minLength: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.mode == .signIn ? "Sign In" : "Create Account")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: role == .caregiver ? "hands.and.sparkles.fill" : "house.heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(role == .caregiver ? Color.careAccentBlue : Color.careAccentTeal)

            Text(viewModel.mode == .signIn ? "Welcome back" : "Join Cura as a \(roleLabel)")
                .font(.careHeading)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private var roleLabel: String {
        switch role {
        case .familyMember: return "Family Member"
        case .caregiver:    return "Caregiver"
        case .admin:        return "Staff Member"
        }
    }

    // MARK: Form

    private var formSection: some View {
        VStack(spacing: Spacing.md) {
            CareCard {
                VStack(spacing: Spacing.md) {
                    emailField
                    passwordField
                    if viewModel.mode == .signUp {
                        confirmPasswordField
                        termsCheckbox
                        signUpButton
                    } else {
                        forgotPasswordRow
                        signInButton
                    }
                }
                .padding(Spacing.md)
            }

            dividerRow

            appleSignInButton

            phoneVerificationLink

            toggleModeRow
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Email address")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            TextField("you@example.com", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(Spacing.sm)
                .background(Color.surfaceDepressed)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Password")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            SecureField("Min. 8 characters", text: $viewModel.password)
                .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                .padding(Spacing.sm)
                .background(Color.surfaceDepressed)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Confirm password")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            SecureField("Re-enter your password", text: $viewModel.confirmPassword)
                .textContentType(.newPassword)
                .padding(Spacing.sm)
                .background(Color.surfaceDepressed)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private var termsCheckbox: some View {
        Button {
            viewModel.termsAccepted.toggle()
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: viewModel.termsAccepted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(viewModel.termsAccepted ? Color.careAccentBlue : Color.textSecondary)
                    .frame(width: 24, height: 24)

                Text("By continuing, you accept the **Terms of Service** and **Privacy Policy**.")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accept Terms of Service and Privacy Policy")
        .accessibilityAddTraits(viewModel.termsAccepted ? .isSelected : [])
    }

    private var signUpButton: some View {
        PrimaryButton(title: "Continue", isLoading: viewModel.isLoading, isDisabled: !viewModel.canSubmitSignUp) {
            Task { await viewModel.signUp(container: container, session: session) }
        }
    }

    private var forgotPasswordRow: some View {
        HStack {
            Spacer()
            Button("Forgot Password?") { }
                .font(.careCaption)
                .foregroundStyle(.careAccentBlue)
        }
    }

    private var signInButton: some View {
        PrimaryButton(title: "Sign In", isLoading: viewModel.isLoading, isDisabled: !viewModel.canSubmitSignIn) {
            Task { await viewModel.signIn(container: container, session: session) }
        }
    }

    private var dividerRow: some View {
        HStack(spacing: Spacing.sm) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            Text("or")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Spacing.xs)
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
    }

    private var appleSignInButton: some View {
        Button {
            // Apple Sign In placeholder
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "apple.logo")
                    .font(.body.weight(.semibold))
                Text("Continue with Apple")
                    .font(.careBodyMedium)
            }
            .foregroundStyle(Color(.label))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
    }

    private var phoneVerificationLink: some View {
        Button {
            // Phone verification placeholder
        } label: {
            Text("Use phone number instead")
                .font(.careCaption)
                .foregroundStyle(.careAccentBlue)
        }
    }

    private var toggleModeRow: some View {
        HStack(spacing: Spacing.xs) {
            Text(viewModel.mode == .signIn ? "Don't have an account?" : "Already have an account?")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            Button(viewModel.mode == .signIn ? "Sign Up" : "Sign In") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.mode = viewModel.mode == .signIn ? .signUp : .signIn
                    viewModel.error = nil
                }
            }
            .font(.careCaption.weight(.semibold))
            .foregroundStyle(.careAccentBlue)
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: Error Card

    private var errorCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.careUrgent)
                .font(.body)
            Text(viewModel.error ?? "")
                .font(.careBody)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                viewModel.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.textSecondary)
            }
            .frame(width: 28, height: 28)
        }
        .padding(Spacing.md)
        .background(Color.careUrgent.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.careUrgent.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: Caregiver Info Card

    private var caregiverInfoCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.careAccentBlue)
                .font(.body)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Application required")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Text("After signing up, you'll complete a caregiver application. Your profile won't be visible to families until approved.")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(Spacing.md)
        .background(Color.careAccentBlue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

// MARK: - Preview

#Preview("Sign Up — Family") {
    NavigationStack {
        AuthView(role: .familyMember, intent: .signUp)
            .environment(ServiceContainer.preview)
            .environment(AppSession.onboardedSignedOut)
    }
}

#Preview("Sign In — Caregiver") {
    NavigationStack {
        AuthView(role: .caregiver, intent: .signIn)
            .environment(ServiceContainer.preview)
            .environment(AppSession.onboardedSignedOut)
    }
}
