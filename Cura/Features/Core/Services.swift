import Foundation
import Observation

// MARK: - Service Protocols

protocol BookingServiceProtocol: Sendable {
    func upcomingBookings() async throws -> [Booking]
    func fetchUpcomingBookings(for caregiverId: UUID) async throws -> [Booking]
    func checkIn(bookingId: UUID) async throws -> Booking
    func checkOut(bookingId: UUID) async throws -> Booking
    func updateTask(_ task: BookingTask, in bookingId: UUID) async throws
}

protocol CareLogServiceProtocol: Sendable {
    func fetchLog(for bookingId: UUID, date: Date) async throws -> DailyCareLog?
    func saveLog(_ log: DailyCareLog) async throws
    func submitHandoff(_ handoff: HandoffRecord) async throws
}

protocol MessagingServiceProtocol: Sendable {
    func fetchThreads(for userId: UUID) async throws -> [MessageThread]
    func fetchMessages(threadId: UUID) async throws -> [Message]
    func sendMessage(threadId: UUID, text: String, isUrgent: Bool, language: LanguageCode) async throws -> Message
}

protocol TranslationServiceProtocol: Sendable {
    func translate(_ text: String, to target: LanguageCode) async throws -> String
    func detectLanguage(_ text: String) async throws -> LanguageCode
}

protocol InsightsServiceProtocol: Sendable {
    func getAlerts(personId: UUID) async throws -> [ConcernAlert]
    func concernAlerts(for personId: UUID) async throws -> [ConcernAlert]
    func acknowledgeAlert(id: UUID) async throws
    func acknowledgeAlert(alertId: UUID) async throws
    func getWeeklySummary(personId: UUID) async throws -> WeeklySummary
    func weeklySummary(for personId: UUID) async throws -> WeeklySummary
    func engineSnapshot(for personId: UUID) async throws -> EngineSnapshot
    func submitAlertFeedback(alertId: UUID, feedback: String) async throws
    func getPatternDetection(personId: UUID) async throws -> PatternDetection?
}

protocol TimelineServiceProtocol: Sendable {
    func fetchTimeline(for lovedOneId: UUID) async throws -> [TimelineEntry]
    func entries(for lovedOneId: UUID, from: Date, to: Date) async throws -> [TimelineEntry]
    func addEntry(_ entry: TimelineEntry) async throws
    func acknowledgeEntry(id: UUID) async throws
    func acknowledge(entryId: UUID) async throws
    func dailyLog(for lovedOneId: UUID, on date: Date) async throws -> DailyCareLog
}

protocol ChatbotServiceProtocol: Sendable {
    func ask(question: String, personId: UUID, userId: UUID) async throws -> ChatbotMessage
    func query(_ text: String, lovedOneId: UUID) async throws -> ChatbotMessage
}

protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String, role: UserRole) async throws -> User
    func deleteAccount() async throws
}

protocol CaregiverServiceProtocol: Sendable {
    func searchCaregivers() async throws -> [Caregiver]
    func saveCaregiver(_ caregiver: Caregiver) async throws
    func unsaveCaregiver(_ caregiver: Caregiver) async throws
    func familyCircleMembers() async throws -> [User]
    func updateMemberPermissions(memberId: String) async throws
    func saveBaseline(_ baseline: BaselineProfile, for lovedOneId: UUID) async throws
}

// MARK: - Service Container

@MainActor
@Observable
final class ServiceContainer {
    let bookingService: any BookingServiceProtocol
    let careLogService: any CareLogServiceProtocol
    let timelineService: any TimelineServiceProtocol
    let messagingService: any MessagingServiceProtocol
    let translationService: any TranslationServiceProtocol
    let insightsService: any InsightsServiceProtocol
    let chatbotService: any ChatbotServiceProtocol
    let authService: any AuthServiceProtocol
    let caregiverService: any CaregiverServiceProtocol

    init(
        bookingService: any BookingServiceProtocol = MockBookingService(),
        careLogService: any CareLogServiceProtocol = MockCareLogService(),
        timelineService: any TimelineServiceProtocol = MockTimelineService(),
        messagingService: any MessagingServiceProtocol = MockMessagingService(),
        translationService: any TranslationServiceProtocol = MockTranslationService(),
        insightsService: any InsightsServiceProtocol = MockInsightsService(),
        chatbotService: any ChatbotServiceProtocol = MockChatbotService(),
        authService: any AuthServiceProtocol = MockAuthService(),
        caregiverService: any CaregiverServiceProtocol = MockCaregiverService()
    ) {
        self.bookingService = bookingService
        self.careLogService = careLogService
        self.timelineService = timelineService
        self.messagingService = messagingService
        self.translationService = translationService
        self.insightsService = insightsService
        self.chatbotService = chatbotService
        self.authService = authService
        self.caregiverService = caregiverService
    }

    static let mock = ServiceContainer()
    static let preview = ServiceContainer()
}

// MARK: - App Session

@MainActor
@Observable
final class AppSession {
    var currentUser: User?
    var currentCaregiver: Caregiver?
    var userRole: UserRole = .caregiver
    var activeRole: UserRole? = nil
    var isAuthenticated: Bool = false
    var onboardingComplete: Bool = false
    var primaryLanguage: LanguageCode = .mr

    static let preview: AppSession = {
        let s = AppSession()
        s.currentUser = SampleData.familyUser
        s.userRole = .familyMember
        s.activeRole = .familyMember
        s.isAuthenticated = true
        s.onboardingComplete = true
        return s
    }()

    static let caregiverPreview: AppSession = {
        let s = AppSession()
        s.currentCaregiver = SampleData.caregiver
        s.userRole = .caregiver
        s.activeRole = .caregiver
        s.isAuthenticated = true
        s.onboardingComplete = true
        return s
    }()

    var familyUser: User? { currentUser }

    var currentRole: UserRole? { activeRole }

    func signIn(user: User, role: UserRole) {
        currentUser = user
        activeRole = role
        userRole = role
        isAuthenticated = true
        onboardingComplete = true
    }

    func signOut() {
        currentUser = nil
        currentCaregiver = nil
        activeRole = nil
        isAuthenticated = false
    }

    static let notOnboarded: AppSession = {
        let s = AppSession()
        s.onboardingComplete = false
        return s
    }()

    static let onboardedSignedOut: AppSession = {
        let s = AppSession()
        s.onboardingComplete = true
        s.isAuthenticated = false
        return s
    }()
}

// MARK: - Mock Services

struct MockBookingService: BookingServiceProtocol {
    func upcomingBookings() async throws -> [Booking] {
        SampleData.upcomingBookings
    }
    func fetchUpcomingBookings(for caregiverId: UUID) async throws -> [Booking] {
        SampleData.upcomingBookings
    }
    func checkIn(bookingId: UUID) async throws -> Booking {
        var b = SampleData.activeBooking
        b.checkInTime = Date()
        b.status = .checkedIn
        return b
    }
    func checkOut(bookingId: UUID) async throws -> Booking {
        var b = SampleData.activeBooking
        b.checkOutTime = Date()
        b.status = .completed
        return b
    }
    func updateTask(_ task: BookingTask, in bookingId: UUID) async throws {}
}

struct MockCareLogService: CareLogServiceProtocol {
    func fetchLog(for bookingId: UUID, date: Date) async throws -> DailyCareLog? { nil }
    func saveLog(_ log: DailyCareLog) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
    func submitHandoff(_ handoff: HandoffRecord) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}

struct MockTimelineService: TimelineServiceProtocol {
    func fetchTimeline(for lovedOneId: UUID) async throws -> [TimelineEntry] { SampleData.timelineEntries }
    func entries(for lovedOneId: UUID, from: Date, to: Date) async throws -> [TimelineEntry] { SampleData.timelineEntries }
    func addEntry(_ entry: TimelineEntry) async throws {}
    func acknowledgeEntry(id: UUID) async throws {}
    func acknowledge(entryId: UUID) async throws {}
    func dailyLog(for lovedOneId: UUID, on date: Date) async throws -> DailyCareLog { SampleData.dailyCareLog }
}

struct MockMessagingService: MessagingServiceProtocol {
    func fetchThreads(for userId: UUID) async throws -> [MessageThread] {
        [SampleData.messageThread]
    }
    func fetchMessages(threadId: UUID) async throws -> [Message] {
        SampleData.messages
    }
    func sendMessage(threadId: UUID, text: String, isUrgent: Bool, language: LanguageCode) async throws -> Message {
        Message(
            threadId: threadId, senderId: SampleData.familyUserID,
            senderName: "Raj", senderRole: .familyMember,
            body: text, originalLanguage: language,
            isUrgent: isUrgent, timestamp: Date()
        )
    }
}

struct MockTranslationService: TranslationServiceProtocol {
    func translate(_ text: String, to target: LanguageCode) async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        if target == .en { return text }
        return "[\(target.displayName)] \(text)"
    }
    func detectLanguage(_ text: String) async throws -> LanguageCode { .en }
}

struct MockInsightsService: InsightsServiceProtocol {
    func getAlerts(personId: UUID) async throws -> [ConcernAlert] { SampleData.activeAlerts }
    func concernAlerts(for personId: UUID) async throws -> [ConcernAlert] { SampleData.activeAlerts }
    func acknowledgeAlert(id: UUID) async throws {}
    func acknowledgeAlert(alertId: UUID) async throws {}
    func getWeeklySummary(personId: UUID) async throws -> WeeklySummary { SampleData.weeklySummary }
    func weeklySummary(for personId: UUID) async throws -> WeeklySummary { SampleData.weeklySummary }
    func engineSnapshot(for personId: UUID) async throws -> EngineSnapshot { EngineSnapshot() }
    func submitAlertFeedback(alertId: UUID, feedback: String) async throws {}
    func getPatternDetection(personId: UUID) async throws -> PatternDetection? { SampleData.patternDetection }
}

struct MockChatbotService: ChatbotServiceProtocol {
    func ask(question: String, personId: UUID, userId: UUID) async throws -> ChatbotMessage {
        try await Task.sleep(nanoseconds: 800_000_000)
        return SampleData.chatbotResponse(for: question)
    }
    func query(_ text: String, lovedOneId: UUID) async throws -> ChatbotMessage {
        try await Task.sleep(nanoseconds: 800_000_000)
        return SampleData.chatbotResponse(for: text)
    }
}

struct MockAuthService: AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> User {
        try await Task.sleep(nanoseconds: 600_000_000)
        return SampleData.familyUser
    }
    func signUp(email: String, password: String, role: UserRole) async throws -> User {
        try await Task.sleep(nanoseconds: 600_000_000)
        return SampleData.familyUser
    }
    func deleteAccount() async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}

struct MockCaregiverService: CaregiverServiceProtocol {
    func searchCaregivers() async throws -> [Caregiver] { SampleData.caregivers }
    func saveCaregiver(_ caregiver: Caregiver) async throws {}
    func unsaveCaregiver(_ caregiver: Caregiver) async throws {}
    func familyCircleMembers() async throws -> [User] { [SampleData.familyUser] }
    func updateMemberPermissions(memberId: String) async throws {}
    func saveBaseline(_ baseline: BaselineProfile, for lovedOneId: UUID) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }
}
