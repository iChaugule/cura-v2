import Foundation
import Observation

// MARK: - Fundamental Enums

enum UserRole: String, Codable, CaseIterable, Sendable {
    case familyMember, caregiver, admin
}

enum LanguageCode: String, Codable, CaseIterable, Sendable {
    case en = "English"
    case hi = "Hindi"
    case mr = "Marathi"

    var displayName: String { rawValue }
}

// MARK: - Alert Tier

enum AlertTier: String, Codable, CaseIterable, Comparable, Sendable {
    case informational, monitorClosely, contactCare, urgent

    private var order: Int {
        switch self {
        case .informational: 0
        case .monitorClosely: 1
        case .contactCare: 2
        case .urgent: 3
        }
    }

    static func < (lhs: AlertTier, rhs: AlertTier) -> Bool { lhs.order < rhs.order }

    var icon: String {
        switch self {
        case .informational:  "info.circle.fill"
        case .monitorClosely: "exclamationmark.triangle.fill"
        case .contactCare:    "phone.fill"
        case .urgent:         "exclamationmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .informational:  "Informational"
        case .monitorClosely: "Monitor closely"
        case .contactCare:    "Contact care team"
        case .urgent:         "Urgent"
        }
    }
}

// MARK: - Visit Status

enum VisitStatus: String, Codable, CaseIterable, Sendable {
    case noVisit, arriving, checkedIn, late, completed, cancelled, replacementNeeded
    case scheduled, confirmed, inProgress

    var label: String {
        switch self {
        case .noVisit:           return "No Visit"
        case .arriving:          return "Arriving"
        case .checkedIn:         return "Active"
        case .late:              return "Late"
        case .completed:         return "Completed"
        case .cancelled:         return "Cancelled"
        case .replacementNeeded: return "Action Needed"
        case .scheduled:         return "Scheduled"
        case .confirmed:         return "Confirmed"
        case .inProgress:        return "In Progress"
        }
    }

    var icon: String {
        switch self {
        case .noVisit:           return "calendar.badge.minus"
        case .arriving:          return "car.fill"
        case .checkedIn:         return "checkmark.circle.fill"
        case .late:              return "clock.badge.exclamationmark.fill"
        case .completed:         return "checkmark.seal.fill"
        case .cancelled:         return "xmark.circle.fill"
        case .replacementNeeded: return "person.badge.plus.fill"
        case .scheduled:         return "calendar"
        case .confirmed:         return "calendar.badge.checkmark"
        case .inProgress:        return "checkmark.circle.fill"
        }
    }
}

// MARK: - Trajectory Label

enum TrajectoryLabel: String, Codable, CaseIterable, Sendable {
    case steady, slightlyChanged, notablyChanged, needsAttention, notRecorded
    case holdingSteady, graduallyNeedingMoreSupport, changedRecently, improving, mixed, notEnoughData

    var displayLabel: String {
        switch self {
        case .steady, .holdingSteady:                    return "Steady"
        case .slightlyChanged:                           return "Slightly different"
        case .notablyChanged:                            return "Notably different"
        case .needsAttention, .graduallyNeedingMoreSupport: return "Needs attention"
        case .changedRecently:                           return "Changed recently"
        case .improving:                                 return "Improving"
        case .mixed:                                     return "Mixed"
        case .notRecorded, .notEnoughData:               return "Not recorded"
        }
    }
}

// MARK: - Sync State

enum SyncState: String, Codable, Sendable {
    case synced = "All saved"
    case syncing = "Saving…"
    case offline = "Offline — queued"
}

// MARK: - Observation Enums

enum ObservationCertainty: String, Codable, CaseIterable, Sendable {
    case directObservation     = "Direct observation"
    case reportedByIncoming    = "Reported by incoming caregiver"
    case inferredFromHomeState = "Inferred from home state"
}

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case scheduled       = "Scheduled"
    case completed       = "Completed"
    case declined        = "Declined"
    case unableToComplete = "Unable to Complete"
    case needsFollowUp   = "Needs Follow-Up"
    case notConfirmed    = "Not Confirmed"
}

// MARK: - Core Models

struct User: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var email: String
    var displayName: String
    var profilePhotoURL: URL?
    var preferredLanguage: LanguageCode
    var roles: [UserRole]
    var createdAt: Date

    var name: String { displayName }
    var role: UserRole { roles.first ?? .familyMember }
}

// MARK: - Loved One

struct LovedOne: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var fullName: String
    var preferredName: String
    var age: Int
    var neighborhood: String
    var address: String
    var primaryLanguage: LanguageCode
    var medicalNotes: String
    var memoryCarePassport: MemoryCarePassport?
    var photoName: String?
    var baselineHydrationML: Int
    var familyOwnerId: UUID?
    var dateOfBirth: Date?
    var photoURL: URL?
    var baseline: BaselineProfile?
    var createdAt: Date = Date()

    var name: String { preferredName.isEmpty ? fullName : preferredName }
    var avatarUrl: URL? { photoURL }
    var countryCode: String? { nil }
    var emergencyContactName: String? { nil }
    var emergencyContactPhone: String? { nil }
    var medicalConditionsSummary: String? { medicalNotes.isEmpty ? nil : medicalNotes }
    var allergies: String? { nil }
}

struct PassportEmergencyContact: Codable, Sendable {
    var name: String
    var relationship: String
    var phone: String
}

struct MemoryCarePassport: Codable, Sendable {
    // Core stored properties
    var preferredName: String
    var likesAndComforts: [String]
    var calmingTechniques: [String]
    var importantPeople: [String]
    var significantPlaces: [String]
    var routineNotes: String
    var safetyNotes: String
    var helpMeFeelSafe: String
    var languagesSpoken: [LanguageCode]
    var memoriesAndStories: String

    // Extended stored properties (all optional for Codable compatibility)
    var fullName: String?
    var dateOfBirth: String?
    var primaryDiagnosis: String?
    var yearsSinceDiagnosis: String?
    var cognitiveStage: String?
    var primaryChallenges: String?
    var specialistName: String?
    var lastAssessmentDate: String?
    var comprehensionLevel: String?
    var bestCommunicationTips: String?
    var communicationAvoid: String?
    var formerHomeDescription: String?
    var typicalWakeTime: String?
    var afternoonPreferences: String?
    var typicalBedtime: String?
    var eveningRoutineSummary: String?
    var personalityDescription: String?
    var comfortingItems: String?
    var distressTriggers: String?
    var earlyWarningSigns: String?
    var deEscalationStrategies: String?
    var sundowingPattern: String?
    var walkingAbility: String?
    var assistiveDevices: String?
    var bathingPreferences: String?
    var dressingPreferences: String?
    var continenceNotes: String?
    var preferredFoods: String?
    var avoidedFoods: String?
    var foodAllergies: String?
    var fluidPreferences: String?
    var textureNeeds: String?
    var eatingAssistanceNotes: String?
    var medicationScheduleSummary: String?
    var medicationAdministrationNotes: String?
    var medicationSideEffectsToWatch: String?
    var wanderingRiskLevel: String?
    var lockedAreaNotes: String?
    var emergencyWord: String?
    var emergencyContacts: [PassportEmergencyContact]?

    // Computed aliases
    var calmingPhrases: [String] { calmingTechniques }
    var primaryLanguage: String? { languagesSpoken.first?.displayName }
    var familyMembersDescription: String? { importantPeople.isEmpty ? nil : importantPeople.joined(separator: "\n") }
    var importantPlaces: String? { significantPlaces.isEmpty ? nil : significantPlaces.joined(separator: "\n") }
    var homeSafetyNotes: String? { safetyNotes.isEmpty ? nil : safetyNotes }
    var morningRoutineSummary: String? { routineNotes.isEmpty ? nil : routineNotes }
    var joyTriggers: String? { likesAndComforts.isEmpty ? nil : likesAndComforts.joined(separator: ", ") }
}

// MARK: - Baseline Profile (loved one's stable health baseline)

enum AppetiteRating: String, Codable, CaseIterable, Sendable, Identifiable {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .fair: return "minus.circle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
}

enum WalkingAbility: String, Codable, CaseIterable, Sendable, Identifiable {
    case independent  = "Independent"
    case withDevice   = "With device (walker/cane)"
    case withAssist   = "Needs assistance"
    case wheelchairPt = "Wheelchair part-time"
    case wheelchairFt = "Wheelchair full-time"
    var id: String { rawValue }
}

enum EveningBehavior: String, Codable, CaseIterable, Sendable, Identifiable {
    case calm           = "Calm and settled"
    case mildlyRestless = "Mildly restless"
    case sundowning     = "Sundowning — more confused"
    case agitated       = "Often agitated"
    var id: String { rawValue }
}

enum RecognitionLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case recognizesAll     = "Recognizes everyone"
    case recognizesClosest = "Recognizes closest family"
    case occasionally      = "Occasionally recognizes family"
    case rarelyRecognizes  = "Rarely recognizes familiar faces"
    var id: String { rawValue }
}

enum ToiletingPattern: String, Codable, CaseIterable, Sendable, Identifiable {
    case independent    = "Independent"
    case promptsNeeded  = "Needs prompting"
    case fullAssistance = "Full assistance"
    case continencePad  = "Uses continence pad"
    var id: String { rawValue }
}

enum MoodRangeLabel: String, Codable, CaseIterable, Sendable, Identifiable {
    case generallyPositive    = "Generally positive"
    case variableWithTriggers = "Variable — triggered by events"
    case frequentlyAnxious    = "Frequently anxious"
    case frequentlySad        = "Frequently sad or withdrawn"
    var id: String { rawValue }
}

enum CommunicationAbilityLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    case verbal       = "Verbal — full sentences"
    case shortPhrases = "Short phrases"
    case singleWords  = "Single words"
    case nonVerbal    = "Mostly non-verbal"
    var id: String { rawValue }
}

struct BaselineProfile: Codable, Sendable, Equatable {
    var wakeTimeHour: Double = 7
    var sleepPattern: String = "Sleeps through the night"
    var appetiteRating: AppetiteRating = .good
    var fluidIntakeTargetMl: Double = 1200
    var walkingAbility: WalkingAbility = .withDevice
    var communicationLevel: CommunicationAbilityLevel = .verbal
    var eveningBehavior: EveningBehavior = .calm
    var recognitionLevel: RecognitionLevel = .recognizesClosest
    var moodRange: MoodRangeLabel = .generallyPositive
    var toiletingPattern: ToiletingPattern = .promptsNeeded

    var formattedWakeTime: String {
        let h = Int(wakeTimeHour)
        let ampm = h < 12 ? "AM" : "PM"
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayH):00 \(ampm)"
    }

    static let `default` = BaselineProfile()
}

// MARK: - Caregiver

struct Caregiver: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var preferredName: String
    var bio: String
    var languages: [LanguageCode]
    var specialties: [String]
    var rating: Double
    var totalVisits: Int
    var verificationBadges: [String]
    var profilePhotoName: String?
    var availability: [String]
    var serviceArea: String
    var hourlyRate: Int = 350
    var yearsExperience: Int = 5
    var cancellationRate: Int = 2
    var onTimePercentage: Int = 97
    var repeatFamilyPercentage: Int = 85
    var matchingReason: String = ""

    var firstName: String {
        preferredName.isEmpty ? (name.components(separatedBy: " ").first ?? name) : preferredName
    }
    var city: String { serviceArea }
    var reviewCount: Int { totalVisits }
    var photoUrl: URL? { nil }
    var isBackgroundChecked: Bool { verificationBadges.contains { $0.lowercased().contains("background") } }
    var isIdentityVerified: Bool { verificationBadges.contains { $0.lowercased().contains("identity") } }
    var isReferencesVerified: Bool { verificationBadges.contains { $0.lowercased().contains("reference") } }
    var dementiaTrainingLevel: String {
        specialties.contains { $0.lowercased().contains("dementia") } ? "Certified" : "Foundational"
    }
    var onTimeRate: Double { Double(onTimePercentage) / 100.0 }
    var completedVisits: Int { totalVisits }
    var repeatFamiliesCount: Int { repeatFamilyPercentage }
    var primaryLanguage: String { languages.first?.displayName ?? "" }
}

// MARK: - Booking

struct Booking: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var lovedOneId: UUID
    var caregiverId: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var visitType: String
    var status: VisitStatus
    var tasks: [BookingTask]
    var estimatedEarnings: Double
    var neighborhood: String
    var address: String
    var checkInTime: Date?
    var checkOutTime: Date?
    var lovedOneName: String
    var lovedOnePreferredName: String
    var familyContactName: String
    var languagePreference: LanguageCode

    var formattedArrivalTime: String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: startTime)
    }
    var formattedCheckInTime: String {
        guard let t = checkInTime else { return "earlier today" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: t)
    }
    var formattedCheckOutTime: String {
        guard let t = checkOutTime else { return "today" }
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: t)
    }
}

struct BookingTask: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var title: String
    var instruction: String?
    var scheduledTime: Date?
    var status: TaskStatus
    var isMedicationRelated: Bool
    var note: String?
    var unableReason: String?
    var completedAt: Date?
}

// MARK: - Daily Care Log (Observable class — shared by reference across sub-views)

@Observable final class DailyCareLog: Identifiable {
    var id: UUID = UUID()
    var bookingId: UUID
    var lovedOneId: UUID
    var caregiverId: UUID
    var date: Date
    var mobilityLog: MobilityLog?
    var sleepLog: SleepLog?
    var foodLog: FoodLog?
    var hydrationLog: HydrationLog?
    var moodLog: MoodLog?
    var communicationLog: CommunicationOrientationLog?
    var contextEvents: [ContextEvent] = []
    var syncState: SyncState = .synced
    var submittedAt: Date?

    init(bookingId: UUID, lovedOneId: UUID, caregiverId: UUID, date: Date = Date()) {
        self.bookingId = bookingId
        self.lovedOneId = lovedOneId
        self.caregiverId = caregiverId
        self.date = date
    }

    var completedDomainCount: Int {
        [mobilityLog != nil, sleepLog != nil, foodLog != nil, hydrationLog != nil,
         moodLog != nil, communicationLog != nil].filter { $0 }.count
    }

    var canSubmit: Bool {
        mobilityLog != nil && sleepLog != nil && foodLog != nil && hydrationLog != nil
    }

    // Domain-level trajectory summaries for family Home view
    var sleepTrajectory: TrajectoryLabel {
        guard let s = sleepLog else { return .notRecorded }
        switch s.comparedToUsual {
        case .same: return .steady
        case .sleptLess: return .notablyChanged
        case .sleptMore: return .slightlyChanged
        case .unableToAssess: return .notRecorded
        case .none: return .notRecorded
        }
    }

    var mealTrajectory: TrajectoryLabel {
        guard let f = foodLog else { return .notRecorded }
        let records = f.meals.compactMap { $0.intake }
        if records.isEmpty { return .notRecorded }
        let refused = records.filter { $0 == .refused || $0 == .aFewBites }.count
        if refused >= 2 { return .needsAttention }
        if records.contains(.aboutHalf) { return .slightlyChanged }
        return .steady
    }

    var hydrationTrajectory: TrajectoryLabel {
        guard let h = hydrationLog else { return .notRecorded }
        let ratio = Double(h.totalML) / Double(max(h.baselineML, 1))
        if ratio < 0.5 { return .needsAttention }
        if ratio < 0.75 { return .notablyChanged }
        if ratio < 0.9 { return .slightlyChanged }
        return .steady
    }

    var mobilityTrajectory: TrajectoryLabel {
        guard let m = mobilityLog else { return .notRecorded }
        switch m.overall {
        case .sameAsUsual: return .steady
        case .alittleMoreHelpNeeded: return .slightlyChanged
        case .noticeablyMoreHelpNeeded: return .notablyChanged
        case .unableToAssess: return .notRecorded
        case .none: return .notRecorded
        }
    }

    var moodTrajectory: TrajectoryLabel {
        guard let m = moodLog else { return .notRecorded }
        switch m.predominantMood {
        case .calm, .comfortable, .cheerful: return .steady
        case .anxious, .restless, .tearful: return .slightlyChanged
        case .agitated, .suspicious, .withdrawn: return .notablyChanged
        case .none: return .notRecorded
        }
    }

    var mealSummaryShort: String {
        guard let f = foodLog, let breakfast = f.meals.first(where: { $0.mealType == .breakfast }) else {
            return "Not recorded"
        }
        return breakfast.intake?.rawValue.components(separatedBy: " ").first ?? "—"
    }

    var hydrationSummaryShort: String {
        guard let h = hydrationLog else { return "Not recorded" }
        return "\(h.totalML) mL"
    }

    var moodSummaryShort: String {
        guard let m = moodLog, let mood = m.predominantMood else { return "Not recorded" }
        return mood.rawValue
    }

    var sleepSummaryShort: String {
        guard let s = sleepLog, let quality = s.quality else { return "Not recorded" }
        return quality.rawValue.components(separatedBy: " ").first ?? "—"
    }

    var confirmedEvents: [String] {
        var events: [String] = []
        if let f = foodLog { events += f.meals.compactMap { m in m.intake.map { "\($0.rawValue) — \(m.mealType.rawValue)" } } }
        if let h = hydrationLog { events.append("Fluid intake: \(h.totalML) mL") }
        if let m = mobilityLog, m.overall != nil { events.append("Mobility: \(m.overall?.rawValue ?? "")") }
        if let s = sleepLog, let q = s.quality { events.append("Sleep: \(q.rawValue)") }
        return events
    }

    var caregiverObservations: [String] {
        var obs: [String] = []
        if let mood = moodLog?.predominantMood { obs.append("Mood: \(mood.rawValue)") }
        if let comm = communicationLog, let cl = comm.communication { obs.append("Communication: \(cl.rawValue)") }
        if let m = moodLog, !m.behaviorEvents.isEmpty { obs.append("\(m.behaviorEvents.count) behavioral event(s) noted") }
        return obs
    }

    var missingInformation: [String] {
        var missing: [String] = []
        if mobilityLog == nil { missing.append("Mobility log not recorded") }
        if sleepLog == nil { missing.append("Sleep log not recorded") }
        if foodLog == nil { missing.append("Meals log not recorded") }
        if hydrationLog == nil { missing.append("Hydration log not recorded") }
        if moodLog == nil { missing.append("Mood log not recorded") }
        return missing
    }

    var uncompletedTaskDescriptions: [String] { [] }

    var summaryText: String {
        let events = confirmedEvents
        let obs = caregiverObservations
        if events.isEmpty && obs.isEmpty {
            return "No care data was recorded for this visit."
        }
        var parts: [String] = []
        if !events.isEmpty { parts.append(events.joined(separator: ". ")) }
        if !obs.isEmpty { parts.append(obs.joined(separator: ". ")) }
        return parts.joined(separator: " ")
    }

    func fillSameAsUsual() {
        let now = Date()
        mobilityLog = MobilityLog(
            overall: .sameAsUsual, walkingAids: [.usedWalker], steadiness: .steady,
            fallEvents: [], movementPain: false, recordedAt: now, certainty: .directObservation)
        sleepLog = SleepLog(
            bedtime: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: now),
            wakeTime: Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: now),
            quality: .wokeOnceOrTwice, nightBehaviors: [], daytimeSleep: .oneShortNap,
            comparedToUsual: .same, reportedBy: .directObservation, recordedAt: now)
        foodLog = FoodLog(
            meals: MealType.allCases.map {
                MealRecord(mealType: $0, intake: .mostlyAte, assistance: .independent,
                           appetiteComparison: .same, swallowingSafetyObservations: [.noneObserved])
            }, recordedAt: now)
        hydrationLog = HydrationLog(
            entries: [HydrationEntry(time: now, amountML: 200, description: "Water"),
                      HydrationEntry(time: now, amountML: 150, description: "Chai"),
                      HydrationEntry(time: now, amountML: 200, description: "Water")],
            refusalCount: 0, signs: [.noneObserved], baselineML: 1100, recordedAt: now)
        moodLog = MoodLog(
            predominantMood: .calm, behaviorEvents: [], calmingStrategiesUsed: [],
            severity: nil, recordedAt: now)
        communicationLog = CommunicationOrientationLog(
            communication: .normalForThem, orientationObservations: [.recognizedCaregiver],
            conversationLength: .same, recordedAt: now)
    }
}

// MARK: - Mobility

struct MobilityLog: Codable, Sendable {
    var overall: MobilityOverall?
    var walkingAids: [WalkingAid]
    var steadiness: Steadiness?
    var fallEvents: [FallEvent]
    var movementPain: Bool?
    var voiceNoteURL: String?
    var recordedAt: Date
    var certainty: ObservationCertainty
}

enum MobilityOverall: String, Codable, CaseIterable, Sendable {
    case sameAsUsual            = "Same as usual"
    case alittleMoreHelpNeeded  = "A little more help needed"
    case noticeablyMoreHelpNeeded = "Noticeably more help needed"
    case unableToAssess         = "Unable to assess"
}

enum WalkingAid: String, Codable, CaseIterable, Sendable {
    case independent           = "Independent"
    case usedCane              = "Used cane"
    case usedWalker            = "Used walker"
    case usedWheelchair        = "Used wheelchair"
    case neededOnePersonAssist = "Needed one-person assist"
    case neededTransferAssist  = "Needed transfer assist"
    case didNotWalk            = "Did not walk today"
}

enum Steadiness: String, Codable, CaseIterable, Sendable {
    case steady               = "Steady"
    case slightlyUnsteady     = "Slightly unsteady"
    case unsteady             = "Unsteady"
    case holdingOnToFurniture = "Holding on to furniture"
}

struct FallEvent: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var type: FallType
    var time: Date
    var note: String = ""
}

enum FallType: String, Codable, CaseIterable, Sendable {
    case nearFall              = "Near-fall"
    case fallNoInjury          = "Fall — no injury"
    case fallWithPossibleInjury = "Fall — possible injury"
}

// MARK: - Sleep

struct SleepLog: Codable, Sendable {
    var bedtime: Date?
    var wakeTime: Date?
    var quality: SleepQuality?
    var nightBehaviors: [NightBehavior]
    var daytimeSleep: DaytimeSleep?
    var comparedToUsual: SleepComparison?
    var reportedBy: ObservationCertainty
    var voiceNoteURL: String?
    var recordedAt: Date

    var approximateHours: Double? {
        guard let b = bedtime, let w = wakeTime else { return nil }
        var diff = w.timeIntervalSince(b)
        if diff < 0 { diff += 86400 }
        return diff / 3600
    }
}

enum SleepQuality: String, Codable, CaseIterable, Sendable {
    case sleptThrough    = "Slept through"
    case wokeOnceOrTwice = "Woke once or twice"
    case wokeFrequently  = "Woke frequently"
    case barelySleep     = "Barely slept"
    case unableToAssess  = "Unable to assess"
}

enum NightBehavior: String, Codable, CaseIterable, Sendable {
    case gotUpAndWandered = "Got up and wandered"
    case calledOut        = "Called out"
    case confusedOnWaking = "Confused on waking"
    case restless         = "Restless"
    case calm             = "Calm"
}

enum DaytimeSleep: String, Codable, CaseIterable, Sendable {
    case none           = "None"
    case oneShortNap    = "One short nap"
    case severalNaps    = "Several naps"
    case sleptMostOfDay = "Slept most of the day"
}

enum SleepComparison: String, Codable, CaseIterable, Sendable {
    case same           = "Same"
    case sleptLess      = "Slept less"
    case sleptMore      = "Slept more"
    case unableToAssess = "Unable to assess"
}

// MARK: - Food

struct FoodLog: Codable, Sendable {
    var meals: [MealRecord]
    var overallNote: String = ""
    var voiceNoteURL: String?
    var recordedAt: Date
}

struct MealRecord: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var mealType: MealType
    var intake: MealIntake?
    var assistance: MealAssistance?
    var appetiteComparison: AppetiteComparison?
    var swallowingSafetyObservations: [SwallowingSafety] = []
    var photoURL: String?
    var note: String = ""
}

enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snacks    = "Snacks"
}

enum MealIntake: String, Codable, CaseIterable, Sendable {
    case ateAll       = "Ate all"
    case mostlyAte    = "Mostly ate"
    case aboutHalf    = "About half"
    case aFewBites    = "A few bites"
    case refused      = "Refused"
    case notOffered   = "Not offered"
    case unableToAssess = "Unable to assess"
}

enum MealAssistance: String, Codable, CaseIterable, Sendable {
    case independent      = "Independent"
    case verbalPrompting  = "Verbal prompting"
    case handOverHand     = "Hand-over-hand"
    case fullyFed         = "Fully fed"
}

enum AppetiteComparison: String, Codable, CaseIterable, Sendable {
    case same           = "Same"
    case less           = "Less"
    case more           = "More"
    case unableToAssess = "Unable to assess"
}

enum SwallowingSafety: String, Codable, CaseIterable, Sendable {
    case coughingDuringMeal            = "Coughing during meal"
    case chokingEpisode                = "Choking episode"
    case wetVoiceAfterEating           = "Wet voice after eating"
    case foodLeftInMouth               = "Food left in mouth"
    case difficultySwallowingMedication = "Difficulty swallowing medication"
    case noneObserved                  = "None observed"
}

// MARK: - Hydration

struct HydrationLog: Codable, Sendable {
    var entries: [HydrationEntry]
    var refusalCount: Int
    var signs: [HydrationSigns]
    var baselineML: Int
    var voiceNoteURL: String?
    var recordedAt: Date

    var totalML: Int { entries.reduce(0) { $0 + $1.amountML } }
}

struct HydrationEntry: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var time: Date
    var amountML: Int
    var description: String = ""
}

enum HydrationSigns: String, Codable, CaseIterable, Sendable {
    case dryMouth         = "Dry mouth"
    case darkUrine        = "Dark urine"
    case reducedUrination = "Reduced urination"
    case noneObserved     = "None observed"
    case unableToAssess   = "Unable to assess"
}

// MARK: - Mood & Behavior

struct MoodLog: Codable, Sendable {
    var predominantMood: MoodState?
    var behaviorEvents: [BehaviorEvent]
    var calmingStrategiesUsed: [CalmingStrategyRecord]
    var severity: BehaviorSeverity?
    var voiceNoteURL: String?
    var recordedAt: Date
}

enum MoodState: String, Codable, CaseIterable, Sendable {
    case calm       = "Calm"
    case comfortable = "Comfortable"
    case cheerful   = "Cheerful"
    case anxious    = "Anxious"
    case restless   = "Restless"
    case withdrawn  = "Withdrawn"
    case tearful    = "Tearful"
    case agitated   = "Agitated"
    case suspicious = "Suspicious"

    var emoji: String {
        switch self {
        case .calm: "😌"; case .comfortable: "🙂"; case .cheerful: "😊"
        case .anxious: "😟"; case .restless: "😤"; case .withdrawn: "😶"
        case .tearful: "😢"; case .agitated: "😠"; case .suspicious: "🤨"
        }
    }

    var isDistressed: Bool {
        switch self {
        case .anxious, .agitated, .suspicious, .tearful, .restless: true
        default: false
        }
    }
}

struct BehaviorEvent: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var type: BehaviorEventType
    var time: Date
    var note: String = ""
}

enum BehaviorEventType: String, Codable, CaseIterable, Sendable {
    case pacing            = "Pacing"
    case repeatedQuestions = "Repeated questions"
    case callingForPerson  = "Calling for person"
    case resistanceToCare  = "Resistance to care"
    case exitSeeking       = "Exit-seeking"
    case shouting          = "Shouting"
    case handWringing      = "Hand-wringing"
}

enum BehaviorSeverity: String, Codable, CaseIterable, Sendable {
    case mild       = "Mild"
    case moderate   = "Moderate"
    case significant = "Significant"
}

struct CalmingStrategyRecord: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var strategy: String
    var didHelp: Bool?
}

// MARK: - Communication & Orientation

struct CommunicationOrientationLog: Codable, Sendable {
    var communication: CommunicationLevel?
    var orientationObservations: [OrientationObservation]
    var conversationLength: ConversationLength?
    var repeatedQuestionCount: Int?
    var voiceNoteURL: String?
    var recordedAt: Date
}

enum CommunicationLevel: String, Codable, CaseIterable, Sendable {
    case normalForThem         = "Normal for them"
    case difficultyFindingWords = "Difficulty finding words"
    case shortPhrasesOnly      = "Short phrases only"
    case gesturesMostly        = "Gestures mostly"
    case lessResponsiveThanUsual = "Less responsive than usual"
    case unableToAssess        = "Unable to assess"
}

enum OrientationObservation: String, Codable, CaseIterable, Sendable {
    case recognizedCaregiver    = "Recognized caregiver"
    case recognizedFamilyMember = "Recognized family member"
    case unsureOfLocation       = "Unsure of location"
    case askedToGoHome          = "Asked to go home"
    case repeatedSameQuestion   = "Repeated the same question"
    case appearedMoreConfused   = "Appeared more confused than usual"
}

enum ConversationLength: String, Codable, CaseIterable, Sendable {
    case same           = "Same"
    case shorter        = "Shorter"
    case muchShorter    = "Much shorter"
    case unableToAssess = "Unable to assess"
}

// MARK: - Handoff

struct HandoffRecord: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var bookingId: UUID
    var outgoingCaregiverId: UUID
    var outgoingCaregiverName: String
    var incomingCaregiverName: String
    var moodSummary: String = ""
    var mealsSummary: String = ""
    var hydrationSummary: String = ""
    var mobilityNotes: String = ""
    var sleepNotes: String = ""
    var medicationNotes: String = ""
    var toiletingNotes: String = ""
    var behavioralObservations: String = ""
    var calmingStrategiesWorked: String = ""
    var remainingTasks: [BookingTask] = []
    var immediateSafetyConcerns: String = ""
    var isUrgentFlag: Bool = false
    var voiceNoteURL: String?
    var submittedAt: Date?
    var acknowledgedAt: Date?
}

// MARK: - Timeline

struct TimelineEntry: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var timestamp: Date
    var type: TimelineEntryType
    var title: String
    var body: String
    var authorName: String
    var authorRole: UserRole
    var alertTier: AlertTier
    var isAcknowledged: Bool = false
    var hasVoiceNote: Bool = false
    var hasPhoto: Bool = false
}

enum TimelineEntryType: String, Codable, Sendable {
    case careLog, observation, voiceNote, handoff, contextEvent, alert, checkIn, checkOut
}

// MARK: - Context Events

struct ContextEvent: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var type: ContextEventType
    var timestamp: Date
    var note: String = ""
}

enum ContextEventType: String, Codable, CaseIterable, Sendable {
    case medicationChange    = "Medication change"
    case doctorVisit         = "Doctor visit"
    case familyVisit         = "Family visit"
    case heatWave            = "Heat wave"
    case hospitalDischarge   = "Hospital discharge"
    case illnessOrInfection  = "Illness or infection"
    case newCaregiver        = "New caregiver"
    case travel              = "Travel or environment change"
    case other               = "Other"

    var icon: String {
        switch self {
        case .medicationChange:   "pill.fill"
        case .doctorVisit:        "stethoscope"
        case .familyVisit:        "person.2.fill"
        case .heatWave:           "sun.max.fill"
        case .hospitalDischarge:  "building.2.fill"
        case .illnessOrInfection: "thermometer.medium"
        case .newCaregiver:       "person.badge.plus.fill"
        case .travel:             "airplane"
        case .other:              "ellipsis.circle.fill"
        }
    }
}

// MARK: - Concern Alert

struct ConcernAlert: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var tier: AlertTier
    var headline: String
    var detail: String
    var domain: String
    var recommendedAction: String
    var alternativeExplanations: [String]
    var missingInformation: [String]
    var confidence: String
    var confidenceReason: String
    var disclaimer: String = "This alert identifies a reported change or safety concern. It is not a diagnosis or medical advice."
    var isAcknowledged: Bool = false
    var createdAt: Date
    var updatedAt: Date
    var supportingObservationSummaries: [String]
    var anchorBaselineDescription: String = ""
    var adaptiveBaselineDescription: String = ""
    var episodeId: UUID = UUID()
}

// MARK: - Message

struct Message: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    var threadId: UUID
    var senderId: UUID
    var senderName: String
    var senderRole: UserRole
    var body: String
    var translatedBody: String?
    var originalLanguage: LanguageCode
    var isUrgent: Bool = false
    var isRead: Bool = false
    var timestamp: Date
    var hasVoiceAttachment: Bool = false
}

struct MessageThread: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    var participantIds: [UUID]
    var participantNames: [String]
    var lovedOneId: UUID
    var lastMessage: Message?
    var unreadCount: Int = 0
    var createdAt: Date = Date()
}

// MARK: - Chatbot

struct ChatbotMessage: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var role: ChatbotRole
    var text: String
    var citations: [ChatbotCitation]
    var timestamp: Date
}

enum ChatbotRole: String, Codable, Sendable {
    case user, assistant
}

struct ChatbotCitation: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var label: String
    var entryCount: Int
    var dateRange: String
    var dateRangeLabel: String { dateRange }
}

// MARK: - Weekly Summary

struct DomainScore: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var domain: String
    var trend: TrajectoryLabel
    var weeklyScores: [Double]
}

enum SummaryChangeDirection: String, Codable, Sendable {
    case improved, declined
}

struct SummaryChange: Codable, Sendable {
    var domain: String
    var direction: SummaryChangeDirection
    var description: String
}

struct WeeklySummary: Codable, Sendable {
    var weekStart: Date
    var weekEnd: Date
    var stableAreas: [String]
    var improvedAreas: [String]
    var declinedAreas: [String]
    var newSymptoms: [String]
    var repeatedSymptoms: [String]
    var alertsGenerated: Int
    var questionsForDoctor: [String]
    var domainSummaries: [String: String]
    var domainScores: [DomainScore] = []

    var whatStayed: [String] { stableAreas }

    var whatChanged: [SummaryChange] {
        let improved = improvedAreas.map { SummaryChange(domain: $0, direction: .improved, description: "\($0) improved this week") }
        let declined = declinedAreas.map { SummaryChange(domain: $0, direction: .declined, description: "\($0) declined this week") }
        return improved + declined
    }
}

// Lightweight AI engine state stub used by WeeklySummaryView
struct EngineSnapshot: Codable, Sendable {
    var id: UUID = UUID()
    var generatedAt: Date = Date()
    var note: String = ""
}

// MARK: - Pattern Detection

struct PatternDetection: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var patternType: String
    var cluster: String?
    var onsetSpeed: String
    var concernLevel: AlertTier
    var trajectory: TrajectoryLabel
    var startDate: Date
    var detectedAt: Date
    var confidence: String
    var confidenceReason: String
    var missingInformation: [String]
    var recommendedAction: String
    var disclaimer: String = "This alert identifies a reported change or safety concern. It is not a diagnosis or medical advice."
    var alternativeExplanations: [String]
}

// MARK: - Engine Observation & Baseline (used by AlertEngine, ClusterMatcher, BaselineManager)

enum EngineObservationCategory: String, Codable, CaseIterable, Sendable {
    case hydration, mobility, mood, vitals, food, sleep, pain, toileting, context, other
}

struct Observation: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var personId: UUID
    var observerId: UUID
    var timestamp: Date
    var category: EngineObservationCategory
    var metric: String = ""
    var qualitativeValue: String = ""
    var numericValue: Double? = nil
    var notes: String = ""
}

enum BaselineState: String, Codable, Sendable {
    case provisional, established
}

struct Baseline: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var personId: UUID
    var metric: String
    var anchorValue: Double? = nil
    var adaptiveValue: Double? = nil
    var state: BaselineState = .provisional
    var lastUpdated: Date = Date()
}
