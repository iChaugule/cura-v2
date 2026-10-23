import SwiftUI

struct CaregiverMessagingView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var threads: [MessageThread] = [SampleData.messageThread]
    @State private var selectedThread: MessageThread?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty && !isLoading {
                    EmptyStateView(
                        icon: "message",
                        title: "No messages",
                        message: "Messages from families will appear here."
                    )
                } else {
                    threadList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedThread) { thread in
                CaregiverMessageThreadView(thread: thread)
            }
        }
    }

    private var threadList: some View {
        List {
            ForEach(threads) { thread in
                Button { selectedThread = thread } label: {
                    threadRow(thread)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.curaBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .background(Color.curaBackground)
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.careAccentBlue.opacity(0.2))
                Text(thread.participantNames.first?.prefix(1).uppercased() ?? "?")
                    .font(.careHeading)
                    .foregroundStyle(.careAccentBlue)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.participantNames.joined(separator: ", "))
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
                    Text(last.translatedBody ?? last.body)
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }
            }

            if thread.unreadCount > 0 {
                ZStack {
                    Circle().fill(Color.careAccentBlue)
                    Text("\(thread.unreadCount)")
                        .font(.careCaptionBold)
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
        .padding(Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message thread with \(thread.participantNames.joined(separator: " and ")).")
    }
}

// MARK: - Caregiver Thread View

struct CaregiverMessageThreadView: View {
    let thread: MessageThread
    @Environment(ServiceContainer.self) private var container
    @State private var messages: [Message] = SampleData.messages
    @State private var newMessageText: String = ""
    @State private var showQuickPhrases = false
    @State private var showOriginal: Message?
    @State private var isUrgent = false

    private let quickPhrases = [
        "I have arrived.",
        "Breakfast is complete.",
        "She is comfortable.",
        "Please call me when you can.",
        "I am leaving now.",
        "Medication reminder was given."
    ]

    var body: some View {
        VStack(spacing: 0) {
            translationBanner
            messageList
            composer
        }
        .navigationTitle(thread.participantNames.first ?? "Messages")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.curaBackground)
        .sheet(item: $showOriginal) { message in
            originalSheet(message)
        }
        .sheet(isPresented: $showQuickPhrases) {
            quickPhrasesSheet
        }
    }

    private var translationBanner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "globe")
                .font(.caption)
                .foregroundStyle(.textSecondary)
            Text("Messages translated between English and Marathi. Original always preserved.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.careAccentBlue.opacity(0.06))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(_ message: Message) -> some View {
        let isFromMe = message.senderRole == .caregiver
        return HStack(alignment: .bottom, spacing: Spacing.xs) {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                if message.isUrgent {
                    Label("Urgent", systemImage: "exclamationmark.circle.fill")
                        .font(.careCaptionBold)
                        .foregroundStyle(.careUrgent)
                }

                Text(message.translatedBody ?? message.body)
                    .font(.careBody)
                    .foregroundStyle(isFromMe ? .white : .textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(isFromMe ? Color.careAccentBlue : Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))

                if message.translatedBody != nil {
                    TranslationLabel(fromLanguage: message.originalLanguage.displayName) {
                        showOriginal = message
                    }
                }

                Text(message.timestamp, style: .relative)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.senderName): \(message.translatedBody ?? message.body)")
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Spacing.xs) {
                Button { showQuickPhrases = true } label: {
                    Image(systemName: "text.bubble.fill")
                        .font(.title3)
                        .foregroundStyle(.careAccentTeal)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Quick phrases")

                TextField("Message…", text: $newMessageText, axis: .vertical)
                    .font(.careBody)
                    .lineLimit(1...4)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.surfaceDepressed)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty ? .textSecondary : .careAccentBlue)
                }
                .disabled(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.surfaceCard)
        }
    }

    private func originalSheet(_ message: Message) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Label("Original message", systemImage: "globe")
                        .font(.careHeading)
                    Text("Language: \(message.originalLanguage.displayName)")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                    Text(message.body)
                        .font(.careBody)
                    Divider()
                    Text("Machine translation — accuracy not guaranteed.")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Original Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showOriginal = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var quickPhrasesSheet: some View {
        NavigationStack {
            List(quickPhrases, id: \.self) { phrase in
                Button {
                    newMessageText = phrase
                    showQuickPhrases = false
                } label: {
                    Text(phrase)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                }
                .frame(minHeight: 44)
            }
            .navigationTitle("Quick Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showQuickPhrases = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sendMessage() {
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let msg = Message(
            threadId: thread.id,
            senderId: SampleData.caregiverID,
            senderName: "Priya",
            senderRole: .caregiver,
            body: text,
            translatedBody: "[\(LanguageCode.en.displayName)] \(text)",
            originalLanguage: .mr,
            isUrgent: isUrgent,
            timestamp: Date()
        )
        messages.append(msg)
        newMessageText = ""
        isUrgent = false
    }
}

#Preview {
    CaregiverMessagingView()
        .environment(ServiceContainer.mock)
        .environment(AppSession.caregiverPreview)
}
