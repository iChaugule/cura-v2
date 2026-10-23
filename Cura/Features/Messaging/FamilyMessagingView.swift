import SwiftUI

// MARK: - Thread List ViewModel

@MainActor
@Observable
final class FamilyMessagingViewModel {
    var threads: [MessageThread] = SampleData.messages.isEmpty ? [] : [SampleData.messageThread]
    var searchText: String = ""
    var isLoading: Bool = false

    var filteredThreads: [MessageThread] {
        guard !searchText.isEmpty else { return threads }
        return threads.filter { thread in
            thread.participantNames.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (thread.lastMessage?.body.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func load(container: ServiceContainer, userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            threads = try await container.messagingService.fetchThreads(for: userId)
        } catch { }
    }
}

// MARK: - Thread List View

struct FamilyMessagingView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = FamilyMessagingViewModel()
    @State private var selectedThread: MessageThread? = nil
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Loading messages…")
                } else if viewModel.filteredThreads.isEmpty {
                    EmptyStateView(
                        icon: "message.fill",
                        title: viewModel.searchText.isEmpty ? "No messages yet" : "No results",
                        message: viewModel.searchText.isEmpty ? "Your caregiver messages will appear here." : "Try a different search term."
                    )
                } else {
                    threadList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search messages")
            .task { await viewModel.load(container: container, userId: session.currentUser?.id ?? SampleData.familyUserID) }
            .navigationDestination(for: MessageThread.self) { thread in
                MessageThreadView(thread: thread)
            }
        }
    }

    private var threadList: some View {
        List {
            ForEach(viewModel.filteredThreads) { thread in
                Button {
                    navigationPath.append(thread)
                } label: {
                    threadRow(thread)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .frame(minHeight: 72)
                .accessibilityLabel(threadAccessibilityLabel(thread))
            }
        }
        .listStyle(.plain)
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            ZStack {
                Circle().fill(Color.careAccentTeal.opacity(0.2))
                Text(String(otherParticipantName(thread).prefix(1)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.careAccentTeal)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(otherParticipantName(thread))
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    if let last = thread.lastMessage {
                        Text(last.timestamp, style: .relative)
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                }
                if let last = thread.lastMessage {
                    HStack(spacing: Spacing.xs) {
                        if last.isUrgent {
                            Text("URGENT")
                                .font(.careCaptionBold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.careUrgent)
                                .clipShape(Capsule())
                        }
                        Text(last.translatedBody ?? last.body)
                            .font(.careBody)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(2)
                    }
                    if last.originalLanguage != LanguageCode.en {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                            Text("Translated from \(last.originalLanguage.displayName)")
                                .font(.careCaption)
                        }
                        .foregroundStyle(.careAccentTeal)
                    }
                }
            }

            if thread.unreadCount > 0 {
                Text("\(thread.unreadCount)")
                    .font(.careCaptionBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.careAccentBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func otherParticipantName(_ thread: MessageThread) -> String {
        let myId = session.currentUser?.id
        if let myId, let idx = thread.participantIds.firstIndex(of: myId) {
            let otherIdx = idx == 0 ? 1 : 0
            if thread.participantNames.indices.contains(otherIdx) {
                return thread.participantNames[otherIdx]
            }
        }
        return thread.participantNames.first ?? "Caregiver"
    }

    private func threadAccessibilityLabel(_ thread: MessageThread) -> String {
        let name = otherParticipantName(thread)
        let unread = thread.unreadCount > 0 ? "\(thread.unreadCount) unread messages." : ""
        let preview = thread.lastMessage.map { "Last message: \($0.translatedBody ?? $0.body)" } ?? ""
        return "\(name). \(unread) \(preview)"
    }
}

// MARK: - Thread View ViewModel

@MainActor
@Observable
final class MessageThreadViewModel {
    var thread: MessageThread
    var messages: [Message] = SampleData.messages
    var draftText: String = ""
    var showOriginalSheet: Bool = false
    var originalSheetMessage: Message? = nil
    var showQuickPhrases: Bool = false
    var translationEnabled: Bool = true
    var isSending: Bool = false

    let quickPhrases: [String] = [
        "Is she comfortable?",
        "Did she eat lunch?",
        "Thank you for today.",
        "How is she feeling?",
        "Please call me when you can.",
        "Has she had her afternoon medication?",
    ]

    init(thread: MessageThread) {
        self.thread = thread
    }

    func send(container: ServiceContainer) async {
        guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let text = draftText
        draftText = ""
        isSending = true
        defer { isSending = false }
        do {
            let sent = try await container.messagingService.sendMessage(threadId: thread.id, text: text, isUrgent: false, language: .en)
            messages.append(sent)
        } catch { }
    }

    func loadMessages(container: ServiceContainer) async {
        do {
            messages = try await container.messagingService.fetchMessages(threadId: thread.id)
        } catch { }
    }
}

// MARK: - Message Thread View

struct MessageThreadView: View {
    let thread: MessageThread
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel: MessageThreadViewModel
    @FocusState private var isInputFocused: Bool

    init(thread: MessageThread) {
        self.thread = thread
        self._viewModel = State(initialValue: MessageThreadViewModel(thread: thread))
    }

    private var otherParticipantName: String {
        let myId = SampleData.familyUserID
        if let idx = thread.participantIds.firstIndex(of: myId) {
            let otherIdx = idx == 0 ? 1 : 0
            if thread.participantNames.indices.contains(otherIdx) {
                return thread.participantNames[otherIdx]
            }
        }
        return thread.participantNames.first ?? "Caregiver"
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            composerBar
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .task { await viewModel.loadMessages(container: container) }
        .sheet(isPresented: $viewModel.showOriginalSheet) { originalSheet }
        .sheet(isPresented: $viewModel.showQuickPhrases) { quickPhrasesSheet }
    }

    // MARK: Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: Message Row

    private func messageRow(_ message: Message) -> some View {
        let isFromMe = message.senderId == session.currentUser?.id

        return HStack(alignment: .bottom, spacing: Spacing.xs) {
            if isFromMe { Spacer(minLength: 48) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: Spacing.xxs) {
                if message.isUrgent {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text("Urgent")
                            .font(.careCaptionBold)
                    }
                    .foregroundStyle(.careUrgent)
                }

                Text(viewModel.translationEnabled ? (message.translatedBody ?? message.body) : message.body)
                    .font(.careBody)
                    .foregroundStyle(isFromMe ? .white : .textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(isFromMe ? Color.careAccentBlue : Color.surfaceCard)
                    .clipShape(
                        .rect(
                            topLeadingRadius: isFromMe ? Radius.xl : Radius.sm,
                            bottomLeadingRadius: Radius.xl,
                            bottomTrailingRadius: isFromMe ? Radius.sm : Radius.xl,
                            topTrailingRadius: Radius.xl
                        )
                    )

                if !isFromMe && message.originalLanguage != LanguageCode.en && message.translatedBody != nil {
                    Button {
                        viewModel.originalSheetMessage = message
                        viewModel.showOriginalSheet = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                            Text("Translated from \(message.originalLanguage.displayName) — see original")
                                .font(.careCaption)
                        }
                        .foregroundStyle(.careAccentTeal)
                    }
                    .frame(minHeight: 36)
                    .accessibilityLabel("Translated from \(message.originalLanguage.displayName). Tap to see original.")
                }

                Text(message.timestamp, style: .time)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }

            if !isFromMe { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isFromMe ? "You" : message.senderName): \(message.translatedBody ?? message.body)\(message.isUrgent ? " (Urgent)" : "")")
    }

    // MARK: Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Button {
                    viewModel.showQuickPhrases = true
                } label: {
                    Image(systemName: "text.bubble.fill")
                        .font(.title3)
                        .foregroundStyle(.careAccentBlue)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Quick phrases")

                TextField("Message \(otherParticipantName)…", text: $viewModel.draftText, axis: .vertical)
                    .font(.careBody)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                    .accessibilityLabel("Message composer")

                Button {
                    // Voice note placeholder
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(Color.careAccentTeal)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Record voice note")

                Button {
                    Task { await viewModel.send(container: container) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.draftText.isEmpty ? .textSecondary : .careAccentBlue)
                }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemBackground))
    }

    // MARK: Original Sheet

    private var originalSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let msg = viewModel.originalSheetMessage {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Original (\(msg.originalLanguage.displayName))")
                            .font(.careSubheading)
                            .foregroundStyle(.textSecondary)
                        Text(msg.body)
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .padding(Spacing.md)
                            .background(Color.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }
                    if let translated = msg.translatedBody {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Translated to English")
                                .font(.careSubheading)
                                .foregroundStyle(.textSecondary)
                            Text(translated)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                                .padding(Spacing.md)
                                .background(Color.careAccentTeal.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        }
                    }
                }
                Spacer()
            }
            .padding(Spacing.lg)
            .navigationTitle("Original Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.showOriginalSheet = false }
                        .accessibilityLabel("Close original message view")
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Quick Phrases Sheet

    private var quickPhrasesSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.quickPhrases, id: \.self) { phrase in
                    Button {
                        viewModel.draftText = phrase
                        viewModel.showQuickPhrases = false
                    } label: {
                        HStack {
                            Text(phrase)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.careAccentBlue)
                                .font(.caption)
                        }
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Quick phrase: \(phrase). Tap to use.")
                }
            }
            .navigationTitle("Quick phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showQuickPhrases = false }
                        .accessibilityLabel("Cancel quick phrases")
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.translationEnabled.toggle()
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "globe")
                    Text(viewModel.translationEnabled ? "Translate: On" : "Translate: Off")
                        .font(.careCaption)
                }
                .foregroundStyle(viewModel.translationEnabled ? .careAccentTeal : .textSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Translation \(viewModel.translationEnabled ? "on" : "off"). Tap to toggle.")
        }
    }
}

// MARK: - Preview

#Preview("Thread List") {
    FamilyMessagingView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}

#Preview("Thread") {
    NavigationStack {
        MessageThreadView(thread: SampleData.messageThread)
    }
    .environment(ServiceContainer.preview)
    .environment(AppSession.preview)
}
