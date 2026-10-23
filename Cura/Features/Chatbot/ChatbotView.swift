import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class ChatbotViewModel {
    var messages: [ChatbotMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var showEmergencyBanner: Bool = false
    var emergencyKeyword: String = ""
    var scrollToBottom: Bool = false
    var lovedOne: LovedOne = SampleData.lovedOne

    private let emergencyKeywords = ["fall", "fell", "choking", "unresponsive", "missing", "collapsed", "unconscious"]

    var quickQuestions: [String] {
        [
            "How has she been this week?",
            "Is she getting worse?",
            "Has she been eating?",
            "When did the walking trouble start?",
            "What should I ask her doctor?",
            "What helped when she got agitated?",
        ]
    }

    func sendMessage(container: ServiceContainer) async {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = inputText
        inputText = ""

        // Emergency interception
        let lowered = text.lowercased()
        if let keyword = emergencyKeywords.first(where: { lowered.contains($0) }) {
            emergencyKeyword = keyword
            showEmergencyBanner = true
            return
        }

        let userMsg = ChatbotMessage(
            role: .user,
            text: text,
            citations: [],
            timestamp: Date()
        )
        messages.append(userMsg)
        scrollToBottom = true
        isLoading = true

        do {
            let response = try await container.chatbotService.query(text, lovedOneId: lovedOne.id)
            messages.append(response)
        } catch {
            messages.append(ChatbotMessage(
                role: .assistant,
                text: "I'm having trouble right now. Please try again in a moment.",
                citations: [],
                timestamp: Date()
            ))
        }
        isLoading = false
        scrollToBottom = true
    }

    func askQuickQuestion(_ question: String, container: ServiceContainer) async {
        inputText = question
        await sendMessage(container: container)
    }
}

// MARK: - Main View

struct ChatbotView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = ChatbotViewModel()
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                disclaimerBanner
                Divider()
                chatScrollView
                Divider()
                inputBar
            }
            .navigationTitle("Ask About \(viewModel.lovedOne.name)")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.showEmergencyBanner {
                    emergencyBannerOverlay
                }
            }
        }
    }

    // MARK: Disclaimer Banner

    private var disclaimerBanner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.careAccentBlue)
                .font(.caption)
            Text("Answers are based only on logged care records. Not medical advice.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.careAccentBlue.opacity(0.06))
    }

    // MARK: Chat Scroll View

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if viewModel.messages.isEmpty {
                        emptyStatePrompt
                    }
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    if viewModel.isLoading {
                        typingIndicator
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .onChange(of: viewModel.scrollToBottom) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    viewModel.scrollToBottom = false
                }
            }
        }
    }

    // MARK: Empty State

    private var emptyStatePrompt: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.careAccentBlue.opacity(0.4))
                .padding(.top, Spacing.xxl)
            Text("Ask me anything about \(viewModel.lovedOne.name)'s care")
                .font(.careSubheading)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
            Text("I can look through logged observations, meals, mood, and routines.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: ChatbotMessage) -> some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.role == .user { Spacer(minLength: 48) }

            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Spacing.xs) {
                Text(message.text)
                    .font(.careBody)
                    .foregroundStyle(message.role == .user ? .white : .textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(message.role == .user ? Color.careAccentBlue : Color.surfaceCard)
                    .clipShape(
                        .rect(
                            topLeadingRadius: message.role == .user ? Radius.xl : Radius.sm,
                            bottomLeadingRadius: Radius.xl,
                            bottomTrailingRadius: message.role == .user ? Radius.sm : Radius.xl,
                            topTrailingRadius: Radius.xl
                        )
                    )

                if message.role == .assistant && !message.citations.isEmpty {
                    citationChips(message.citations)
                }

                Text(message.timestamp, style: .time)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Cura"): \(message.text)")
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.careAccentBlue, Color.careAccentTeal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }

    private func citationChips(_ citations: [ChatbotCitation]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(Array(citations.enumerated()), id: \.offset) { index, citation in
                    citationChip(citation, index: index + 1)
                }
            }
        }
    }

    private func citationChip(_ citation: ChatbotCitation, index: Int) -> some View {
        Button {
            // TODO: open timeline filtered to these entries
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                Text("[\(index)] \(citation.entryCount) entries · \(citation.dateRangeLabel)")
                    .font(.careCaption)
            }
            .foregroundStyle(.careAccentBlue)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.careAccentBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Source \(index): \(citation.entryCount) timeline entries from \(citation.dateRangeLabel). Tap to view.")
    }

    // MARK: Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            assistantAvatar
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.textSecondary)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.surfaceCard)
            .clipShape(
                .rect(
                    topLeadingRadius: Radius.sm,
                    bottomLeadingRadius: Radius.xl,
                    bottomTrailingRadius: Radius.xl,
                    topTrailingRadius: Radius.xl
                )
            )
            Spacer()
        }
        .accessibilityLabel("Cura is thinking")
    }

    // MARK: Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            quickQuestionsRow
            HStack(spacing: Spacing.sm) {
                TextField("Ask about \(viewModel.lovedOne.name)…", text: $viewModel.inputText, axis: .vertical)
                    .font(.careBody)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .onSubmit {
                        Task { await viewModel.sendMessage(container: container) }
                    }
                    .accessibilityLabel("Message input field")

                Button {
                    Task { await viewModel.sendMessage(container: container) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.inputText.isEmpty ? .textSecondary : .careAccentBlue)
                }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(.systemBackground))
        }
    }

    private var quickQuestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(viewModel.quickQuestions, id: \.self) { question in
                    Button {
                        Task { await viewModel.askQuickQuestion(question, container: container) }
                    } label: {
                        Text(question)
                            .font(.careCaption)
                            .foregroundStyle(.careAccentBlue)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.careAccentBlue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: 36)
                    .accessibilityLabel("Quick question: \(question)")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: Emergency Banner

    private var emergencyBannerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { viewModel.showEmergencyBanner = false }
            VStack(spacing: Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.careUrgent)
                Text("This sounds urgent")
                    .font(.careDisplayMedium)
                    .foregroundStyle(.textPrimary)
                Text("If \(viewModel.lovedOne.name) needs help right now, please contact emergency services or your caregiver immediately. Cura is not an emergency response service.")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: Spacing.sm) {
                    emergencyActionButton(
                        label: "Call 911 (Emergency)",
                        icon: "phone.fill.badge.plus",
                        color: .careUrgent
                    )
                    emergencyActionButton(
                        label: "Call the caregiver",
                        icon: "phone.fill",
                        color: .careAttention
                    )
                    Button("Continue with Cura") {
                        viewModel.showEmergencyBanner = false
                    }
                    .font(.careBodyMedium)
                    .foregroundStyle(.textSecondary)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Continue chatting with Cura")
                }
            }
            .padding(Spacing.xl)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .padding(.horizontal, Spacing.md)
        }
    }

    private func emergencyActionButton(label: String, icon: String, color: Color) -> some View {
        Button {
            // Deep-link to phone
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                Text(label).font(.careBodyMedium)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview {
    ChatbotView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
