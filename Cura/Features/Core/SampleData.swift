import Foundation

// All data in this file is fictional demonstration data for development and preview purposes only.
// No real individuals, medical records, or care relationships are represented.

enum SampleData {
    // MARK: - Stable IDs
    static let familyUserID     = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let caregiverUserID  = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let caregiverID      = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let caregiver2ID     = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    static let lovedOneID       = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let activeBookingID  = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let messageThreadID  = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
}

// MARK: - Users
extension SampleData {
    static let familyUser = User(
        id: familyUserID,
        email: "raj.rao@example.com",
        displayName: "Raj Rao",
        profilePhotoURL: nil,
        preferredLanguage: .en,
        roles: [.familyMember],
        createdAt: Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    )

    static let caregiverUser = User(
        id: caregiverUserID,
        email: "priya.sharma@example.com",
        displayName: "Priya Sharma",
        profilePhotoURL: nil,
        preferredLanguage: .mr,
        roles: [.caregiver],
        createdAt: Calendar.current.date(byAdding: .month, value: -8, to: Date())!
    )
}

// MARK: - Loved One
extension SampleData {
    static let lovedOne = LovedOne(
        id: lovedOneID,
        fullName: "Meena Rao",
        preferredName: "Aaji",
        age: 83,
        neighborhood: "Shivaji Nagar",
        address: "Flat 4B, Shivaji Nagar, Pune 411005",
        primaryLanguage: .mr,
        medicalNotes: "Moderate Alzheimer's disease. Hypertension on Amlodipine 5mg. High fall risk — uses walker. Soft diet. Evening restlessness.",
        memoryCarePassport: MemoryCarePassport(
            preferredName: "Aaji",
            likesAndComforts: [
                "Morning cardamom chai",
                "Lata Mangeshkar and Marathi bhajans",
                "Looking at the family photo album",
                "Sitting by the east window in the morning",
                "Light jasmine fragrance"
            ],
            calmingTechniques: [
                "Offer tea and sit beside her quietly",
                "Play Marathi music softly",
                "Open the family photo album",
                "Speak slowly in Marathi — do not rush",
                "Redirect to folding towels or light household activity"
            ],
            importantPeople: [
                "Raj (grandson) — she lights up when he visits",
                "Late husband 'Appa' — she may ask about him",
                "Daughter Sunita — calls every Sunday afternoon"
            ],
            significantPlaces: [
                "Grew up in Nashik — may ask to 'go home to Nashik'",
                "Has lived in this flat for 40 years",
                "Temple two streets away — used to walk there daily"
            ],
            routineNotes: "Wakes ~6:30 am. Chai by 7 am. Morning walk with walker. Lunch 1 pm. Rest 2–4 pm. Evening prayer 5 pm. Dinner 7:30 pm. Bedtime 9 pm.",
            safetyNotes: "High fall risk. Always use walker on hard floors. Bathroom grab bars in place. Lock front door — she may wander. Do not leave alone near stairs.",
            helpMeFeelSafe: "Speak in Marathi and use her name. Never argue or correct — agree and redirect. If upset, offer chai and sit quietly. She trusts calm, slow voices. She may not recognise you every day — introduce yourself gently each time.",
            languagesSpoken: [.mr, .hi],
            memoriesAndStories: "Taught primary school in Nashik for 30 years. Very proud of her students. Loves talking about Diwali and Ganesh Chaturthi in Nashik."
        ),
        photoName: nil,
        baselineHydrationML: 1100,
        familyOwnerId: familyUserID,
        baseline: BaselineProfile(
            wakeTimeHour: 6.5,
            sleepPattern: "1–2 wake-ups",
            appetiteRating: .good,
            fluidIntakeTargetMl: 1100,
            walkingAbility: .withDevice,
            communicationLevel: .shortPhrases,
            eveningBehavior: .mildlyRestless,
            recognitionLevel: .recognizesClosest,
            moodRange: .variableWithTriggers,
            toiletingPattern: .promptsNeeded
        )
    )
}

// MARK: - Passport
extension SampleData {
    static var passport: MemoryCarePassport {
        lovedOne.memoryCarePassport ?? MemoryCarePassport(
            preferredName: "Aaji",
            likesAndComforts: ["Morning cardamom chai"],
            calmingTechniques: ["Offer tea and sit beside her quietly"],
            importantPeople: ["Raj (grandson)"],
            significantPlaces: ["Nashik"],
            routineNotes: "Wakes ~6:30 am.",
            safetyNotes: "High fall risk.",
            helpMeFeelSafe: "Speak in Marathi.",
            languagesSpoken: [.mr],
            memoriesAndStories: ""
        )
    }
}

// MARK: - Caregivers
extension SampleData {
    static let caregiver = Caregiver(
        id: caregiverID,
        name: "Priya Sharma",
        preferredName: "Priya",
        bio: "6+ years in memory care and dementia support. Calm, patient approach. Specialised in evening restlessness and mobility assistance. Fluent in Marathi, Hindi, and English.",
        languages: [.mr, .hi, .en],
        specialties: ["Memory Care", "Dementia Routine Support", "Mobility Assistance", "Evening Restlessness"],
        rating: 4.9,
        totalVisits: 312,
        verificationBadges: ["ID Verified", "Background Check", "First Aid Certified"],
        profilePhotoName: nil,
        availability: ["Mon–Fri 7 am–2 pm", "Weekends available"],
        serviceArea: "Kothrud, Aundh, Baner — Pune",
        hourlyRate: 350,
        yearsExperience: 6,
        cancellationRate: 2,
        onTimePercentage: 97,
        repeatFamilyPercentage: 88,
        matchingReason: "Priya speaks Marathi, has six years of dementia-care experience, and has supported families managing evening restlessness."
    )

    static let caregiver2 = Caregiver(
        id: caregiver2ID,
        name: "Anjali Mane",
        preferredName: "Anjali",
        bio: "4 years of overnight and evening care experience. Gentle approach. Experienced with sundowning and nighttime wandering. Speaks Marathi and Hindi.",
        languages: [.mr, .hi],
        specialties: ["Evening Care", "Overnight Support", "Sundowning", "Wandering Safety"],
        rating: 4.6,
        totalVisits: 178,
        verificationBadges: ["ID Verified", "Background Check"],
        profilePhotoName: nil,
        availability: ["Mon–Sun 2 pm–10 pm", "Overnight available"],
        serviceArea: "Kothrud, Shivaji Nagar, Deccan — Pune",
        hourlyRate: 320,
        yearsExperience: 4,
        cancellationRate: 3,
        onTimePercentage: 94,
        repeatFamilyPercentage: 76,
        matchingReason: "Anjali specialises in evening and overnight care, and has four years of sundowning and wandering-safety experience."
    )

    static let caregivers: [Caregiver] = [caregiver, caregiver2]
}

// MARK: - Bookings & Tasks
extension SampleData {
    static let sampleTasks: [BookingTask] = {
        let cal = Calendar.current; let now = Date()
        return [
            BookingTask(title: "Morning Chai & Breakfast",
                        instruction: "Aaji likes cardamom chai. Serve with soft idli or upma — soft foods only. Sit with her during breakfast.",
                        scheduledTime: cal.date(bySettingHour: 7, minute: 30, second: 0, of: now),
                        status: .completed, isMedicationRelated: false,
                        note: "Ate three-quarters of her breakfast. Enjoyed the chai.", completedAt: cal.date(byAdding: .hour, value: -3, to: now)),
            BookingTask(title: "Medication Reminder — Amlodipine 5 mg",
                        instruction: "Remind Aaji to take her Amlodipine tablet with water after breakfast. Reminder only — do not administer.",
                        scheduledTime: cal.date(bySettingHour: 8, minute: 0, second: 0, of: now),
                        status: .notConfirmed, isMedicationRelated: true),
            BookingTask(title: "Morning Walk",
                        instruction: "15–20 min walk with walker around the building. Ensure grip slippers. Do not rush.",
                        scheduledTime: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now),
                        status: .completed, isMedicationRelated: false,
                        note: "10-minute indoor walk. She was steady.", completedAt: cal.date(byAdding: .hour, value: -2, to: now)),
            BookingTask(title: "Bathing & Grooming",
                        instruction: "Assist with bath if she agrees. She may resist — offer sponge bath as alternative.",
                        scheduledTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: now),
                        status: .scheduled, isMedicationRelated: false),
            BookingTask(title: "Hydration Checks",
                        instruction: "Offer water or coconut water every 30 min. Use preferred blue cup. Log each drink. Target 500 mL before noon.",
                        scheduledTime: nil,
                        status: .scheduled, isMedicationRelated: false)
        ]
    }()

    static let activeBooking: Booking = {
        let cal = Calendar.current; let now = Date()
        let start = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let end   = cal.date(bySettingHour: 14, minute: 0, second: 0, of: now)!
        var b = Booking(
            id: activeBookingID,
            lovedOneId: lovedOneID,
            caregiverId: caregiverID,
            date: now, startTime: start, endTime: end,
            visitType: "Morning & Midday Care",
            status: .checkedIn,
            tasks: sampleTasks,
            estimatedEarnings: 840,
            neighborhood: "Shivaji Nagar",
            address: "Flat 4B, Shivaji Nagar, Pune 411005",
            lovedOneName: "Meena Rao",
            lovedOnePreferredName: "Aaji",
            familyContactName: "Raj Rao",
            languagePreference: .mr
        )
        b.checkInTime = cal.date(bySettingHour: 8, minute: 3, second: 0, of: now)
        return b
    }()

    static let upcomingBookings: [Booking] = {
        let cal = Calendar.current; let now = Date()
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: now)! }
        func at(_ h: Int, _ m: Int, on base: Date) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: base)!
        }
        return [
            activeBooking,
            Booking(id: UUID(), lovedOneId: lovedOneID, caregiverId: caregiver2ID,
                    date: day(0), startTime: at(14, 0, on: day(0)), endTime: at(20, 0, on: day(0)),
                    visitType: "Evening Care", status: .scheduled, tasks: [],
                    estimatedEarnings: 640, neighborhood: "Shivaji Nagar",
                    address: "Flat 4B, Shivaji Nagar, Pune 411005",
                    lovedOneName: "Meena Rao", lovedOnePreferredName: "Aaji",
                    familyContactName: "Raj Rao", languagePreference: .mr),
            Booking(id: UUID(), lovedOneId: lovedOneID, caregiverId: caregiverID,
                    date: day(1), startTime: at(8, 0, on: day(1)), endTime: at(14, 0, on: day(1)),
                    visitType: "Morning & Midday Care", status: .confirmed, tasks: [],
                    estimatedEarnings: 840, neighborhood: "Shivaji Nagar",
                    address: "Flat 4B, Shivaji Nagar, Pune 411005",
                    lovedOneName: "Meena Rao", lovedOnePreferredName: "Aaji",
                    familyContactName: "Raj Rao", languagePreference: .mr)
        ]
    }()
}

// MARK: - Timeline
extension SampleData {
    static let timelineEntries: [TimelineEntry] = {
        let cal = Calendar.current; let now = Date()
        func at(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: now)!
        }
        return [
            TimelineEntry(timestamp: at(8, 3), type: .checkIn,
                          title: "Priya checked in",
                          body: "Priya arrived and checked in at 8:03 AM.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational),
            TimelineEntry(timestamp: at(8, 20), type: .careLog,
                          title: "Breakfast served",
                          body: "Aaji ate about three-quarters of breakfast — idli and cardamom chai. Appetite appeared good.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational),
            TimelineEntry(timestamp: at(8, 35), type: .careLog,
                          title: "Medication reminder given",
                          body: "Amlodipine 5 mg reminder given. Not yet confirmed as taken — reminder only.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational),
            TimelineEntry(timestamp: at(9, 10), type: .careLog,
                          title: "150 mL water recorded",
                          body: "Offered water in her preferred blue cup. Drank approximately 150 mL.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational),
            TimelineEntry(timestamp: at(9, 45), type: .careLog,
                          title: "Morning walk completed",
                          body: "10-minute indoor walk with walker around the flat. Steady throughout. No falls.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational, hasVoiceNote: true),
            TimelineEntry(timestamp: at(10, 5), type: .voiceNote,
                          title: "Voice update from Priya",
                          body: "She ate a small breakfast and drank some water. She was tired but comfortable.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .informational, hasVoiceNote: true),
            TimelineEntry(timestamp: at(11, 20), type: .observation,
                          title: "Appeared more tired than usual",
                          body: "Aaji appeared more fatigued than usual after the walk. Resting comfortably near the window now.",
                          authorName: "Priya Sharma", authorRole: .caregiver, alertTier: .monitorClosely)
        ]
    }()
}

// MARK: - Daily Care Log
extension SampleData {
    static let dailyCareLog: DailyCareLog = {
        let log = DailyCareLog(bookingId: activeBookingID, lovedOneId: lovedOneID, caregiverId: caregiverID)
        let now = Date()
        let cal = Calendar.current

        log.mobilityLog = MobilityLog(
            overall: .alittleMoreHelpNeeded,
            walkingAids: [.usedWalker],
            steadiness: .steady,
            fallEvents: [],
            movementPain: false,
            recordedAt: cal.date(bySettingHour: 9, minute: 50, second: 0, of: now)!,
            certainty: .directObservation
        )
        log.sleepLog = SleepLog(
            bedtime: cal.date(bySettingHour: 21, minute: 0, second: 0, of: now)!,
            wakeTime: cal.date(bySettingHour: 6, minute: 30, second: 0, of: now)!,
            quality: .wokeOnceOrTwice,
            nightBehaviors: [.restless],
            daytimeSleep: .oneShortNap,
            comparedToUsual: .same,
            reportedBy: .directObservation,
            recordedAt: cal.date(bySettingHour: 8, minute: 10, second: 0, of: now)!
        )
        log.foodLog = FoodLog(
            meals: [
                MealRecord(mealType: .breakfast, intake: .mostlyAte, assistance: .independent,
                           appetiteComparison: .same, swallowingSafetyObservations: [.noneObserved]),
                MealRecord(mealType: .lunch, intake: .aboutHalf, assistance: .verbalPrompting,
                           appetiteComparison: .less, swallowingSafetyObservations: [.noneObserved]),
                MealRecord(mealType: .dinner),
                MealRecord(mealType: .snacks)
            ],
            recordedAt: cal.date(bySettingHour: 13, minute: 30, second: 0, of: now)!
        )
        log.hydrationLog = HydrationLog(
            entries: [
                HydrationEntry(time: cal.date(bySettingHour: 7, minute: 15, second: 0, of: now)!, amountML: 150, description: "Chai"),
                HydrationEntry(time: cal.date(bySettingHour: 9, minute: 10, second: 0, of: now)!, amountML: 150, description: "Water"),
                HydrationEntry(time: cal.date(bySettingHour: 11, minute: 0, second: 0, of: now)!, amountML: 100, description: "Coconut water"),
                HydrationEntry(time: cal.date(bySettingHour: 13, minute: 0, second: 0, of: now)!, amountML: 150, description: "Water")
            ],
            refusalCount: 2,
            signs: [.noneObserved],
            baselineML: 1100,
            recordedAt: cal.date(bySettingHour: 13, minute: 30, second: 0, of: now)!
        )
        log.moodLog = MoodLog(
            predominantMood: .comfortable,
            behaviorEvents: [],
            calmingStrategiesUsed: [],
            severity: nil,
            recordedAt: cal.date(bySettingHour: 13, minute: 30, second: 0, of: now)!
        )
        return log
    }()
}

// MARK: - Alerts
extension SampleData {
    static let activeAlerts: [ConcernAlert] = [
        ConcernAlert(
            tier: .monitorClosely,
            headline: "Fluid intake below usual for 3 days",
            detail: "Aaji's recorded fluid intake has been below her usual 1,100 mL baseline for three consecutive days. Priya and Anjali both reported this independently.",
            domain: "hydration",
            recommendedAction: "Watch fluid intake closely over the next 24 hours. Check for signs of dry mouth or reduced urination. Contact her care team if intake stays low.",
            alternativeExplanations: [
                "Recent heat wave (logged 3 days ago) may be reducing appetite for fluids.",
                "New medication started on day 32 — worth mentioning to her doctor."
            ],
            missingInformation: ["Urine colour not recorded for 2 of the 3 days."],
            confidence: "Moderate",
            confidenceReason: "Four days of intake data from two caregivers. Urination information missing for two days.",
            isAcknowledged: false,
            createdAt: Calendar.current.date(byAdding: .hour, value: -18, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
            supportingObservationSummaries: [
                "Fluid intake 550 mL (baseline: 1,100 mL) — Priya Sharma, Day 1",
                "Fluid intake 620 mL (baseline: 1,100 mL) — Anjali Mane, Day 2",
                "Fluid intake 480 mL (baseline: 1,100 mL) — Priya Sharma, Day 3"
            ]
        ),
        ConcernAlert(
            tier: .informational,
            headline: "Walking assistance slightly increased",
            detail: "Over the last two weeks, both caregivers have recorded that Aaji needed a little more walking assistance than her usual baseline. The change has been gradual.",
            domain: "mobility",
            recommendedAction: "Continue monitoring. Mention at her next medical appointment.",
            alternativeExplanations: [
                "This change began around when a new caregiver started — may partly reflect recording differences.",
                "No falls reported; overall safety appears stable."
            ],
            missingInformation: [],
            confidence: "Moderate",
            confidenceReason: "Consistent reports across two caregivers over 14 days.",
            isAcknowledged: false,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            supportingObservationSummaries: [
                "\"A little more help needed\" recorded on 9 of 14 days",
                "No falls or near-falls in this period"
            ]
        )
    ]
}

// MARK: - Messages
extension SampleData {
    static let messages: [Message] = [
        Message(threadId: messageThreadID, senderId: caregiverID, senderName: "Priya",
                senderRole: .caregiver,
                body: "Aaji jeva karun jhali. Tini ti puri khali nahi pan chai gheli. (Aaji has had her meal. She didn't finish it all but she had her chai.)",
                translatedBody: "Aaji has finished her meal. She didn't eat everything but she had her chai.",
                originalLanguage: .mr, timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!),
        Message(threadId: messageThreadID, senderId: familyUserID, senderName: "Raj",
                senderRole: .familyMember,
                body: "Thank you, Priya. Did she drink enough water today?",
                translatedBody: "Dhanyavad, Priya. Tini aaj pursel pani pyali ka?",
                originalLanguage: .en, timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!),
        Message(threadId: messageThreadID, senderId: caregiverID, senderName: "Priya",
                senderRole: .caregiver,
                body: "Thodi kami pyali aaj. Mee tilas blue cup madhe water dile pan don vela tiney nakar dila. Mee laksha thevin. (She drank a little less today. I offered water in the blue cup but she declined twice. I'll keep an eye on it.)",
                translatedBody: "She drank a little less today. I offered water in the blue cup but she declined twice. I'll keep watching.",
                originalLanguage: .mr, timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!)
    ]

    static let messageThread = MessageThread(
        id: messageThreadID,
        participantIds: [familyUserID, caregiverID],
        participantNames: ["Raj Rao", "Priya Sharma"],
        lovedOneId: lovedOneID,
        lastMessage: messages.last,
        unreadCount: 1
    )
}

// MARK: - Weekly Summary
extension SampleData {
    static let weeklySummary = WeeklySummary(
        weekStart: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
        weekEnd: Date(),
        stableAreas: ["Sleep", "Mood", "Communication"],
        improvedAreas: [],
        declinedAreas: ["Hydration", "Mobility"],
        newSymptoms: ["Increased walking assistance needed (gradual, 2 weeks)"],
        repeatedSymptoms: ["Evening restlessness (ongoing, clustered 4:30–7:00 PM)"],
        alertsGenerated: 2,
        questionsForDoctor: [
            "Fluid intake has been below her usual 1,100 mL baseline for several days — is this concerning given her current medication?",
            "She has been needing slightly more walking assistance over the last two weeks. Should we adjust her physiotherapy?",
            "She started a new medication on [date] — are any of these changes possibly related?",
            "Evening restlessness has been consistently occurring between 4:30 and 7:00 PM for the last 3 weeks. Any guidance on management?"
        ],
        domainSummaries: [
            "hydration": "Below baseline 5 of 7 days",
            "mobility": "Needing a little more assistance this week",
            "sleep": "Steady — waking once or twice, one short nap",
            "mood": "Calm or comfortable most days; restless in evenings"
        ],
        domainScores: [
            DomainScore(domain: "Hydration", trend: .notablyChanged, weeklyScores: [75, 68, 60, 72, 58, 65, 62]),
            DomainScore(domain: "Mobility",  trend: .slightlyChanged, weeklyScores: [80, 78, 75, 76, 74, 72, 73]),
            DomainScore(domain: "Sleep",     trend: .steady, weeklyScores: [82, 80, 85, 82, 78, 83, 81]),
            DomainScore(domain: "Mood",      trend: .steady, weeklyScores: [85, 82, 88, 84, 80, 86, 83])
        ]
    )
}

// MARK: - Pattern Detection
extension SampleData {
    static let patternDetection = PatternDetection(
        id: UUID(),
        patternType: "multi_day_hydration_decline",
        cluster: "possible_dehydration",
        onsetSpeed: "subacute",
        concernLevel: .monitorClosely,
        trajectory: .notablyChanged,
        startDate: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
        detectedAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
        confidence: "Moderate",
        confidenceReason: "Four days of corroborated intake data; urination information missing for two days.",
        missingInformation: ["Urine colour", "Temperature", "Swallowing check"],
        recommendedAction: "contact_healthcare_professional_if_persists",
        disclaimer: "This alert identifies a reported change or safety concern. It is not a diagnosis or medical advice.",
        alternativeExplanations: [
            "Heat wave logged 3 days ago",
            "New medication started 7 days ago"
        ]
    )
}

// MARK: - Chatbot
extension SampleData {
    static func chatbotResponse(for question: String) -> ChatbotMessage {
        let q = question.lowercased()

        let text: String
        let citations: [ChatbotCitation]

        if q.contains("worse") || q.contains("getting worse") {
            text = "Here's what the records show over the last three weeks.\n\n**Steady:** Eating, sleep, mood, and communication are all within her usual range.\n\n**Changed:** Walking has needed a little more help. Priya and Anjali have both recorded \"a little more help needed\" on 9 of the last 14 days, compared to 2 of 14 in the two weeks before that.\n\n**Not enough information:** Toileting hasn't been recorded on 6 of the last 14 days.\n\nAaji also started a new medication 7 days ago, which is worth mentioning to her doctor.\n\nThese observations describe her support needs, not her diagnosis — only her doctor can assess that. I've put together questions you might bring to her next appointment."
            citations = [
                ChatbotCitation(label: "11 mobility entries", entryCount: 11, dateRange: "Jun 20 – Jul 10")
            ]
        } else if q.contains("eat") || q.contains("food") || q.contains("meal") {
            text = "Based on this week's records:\n\n**Breakfast:** She mostly ate or ate all of breakfast on 5 of 7 days — within her usual range.\n\n**Lunch:** Appetite at lunch was slightly reduced on 4 of 7 days. She ate about half on three of those days.\n\n**Dinner:** Dinner was recorded on 5 of 7 days. She ate most of her dinner on 4 of those days.\n\nNo swallowing concerns were noted this week. Priya noted she particularly enjoyed the morning chai."
            citations = [
                ChatbotCitation(label: "14 meal entries", entryCount: 14, dateRange: "Jul 1–7")
            ]
        } else if q.contains("sleep") {
            text = "Sleep records from this week show she's been sleeping roughly 8–9 hours at night, waking once or twice. This is within her usual range.\n\nDaytime naps: She had one short nap on 4 of 7 days.\n\nSleep was not recorded on Tuesday and Wednesday — so I can't say for certain what those nights were like."
            citations = [
                ChatbotCitation(label: "5 sleep entries", entryCount: 5, dateRange: "Jul 1–7")
            ]
        } else if q.contains("doctor") || q.contains("ask") {
            text = "Based on the last three weeks of care records, here are questions worth raising at her next appointment:\n\n1. Fluid intake has been below her usual baseline for several days — is this a concern given her current medication?\n2. She has gradually needed a little more walking assistance over two weeks. Should her physiotherapy be reviewed?\n3. She started a new medication 7 days ago — could any recent changes be related?\n4. Evening restlessness has been consistently occurring between 4:30–7:00 PM. Any guidance on management?"
            citations = [
                ChatbotCitation(label: "This week's summary", entryCount: 0, dateRange: "Jul 1–7")
            ]
        } else {
            text = "Based on this week's records, Aaji has been doing fairly steadily overall. Sleep and mood are within her usual range. She's needed a little more walking assistance than usual, and fluid intake has been somewhat below her baseline of 1,100 mL on a few days. Eating has been mostly within her usual range.\n\nIs there a specific area you'd like to know more about?"
            citations = [
                ChatbotCitation(label: "Weekly summary", entryCount: 0, dateRange: "Jul 1–7")
            ]
        }

        return ChatbotMessage(
            role: .assistant,
            text: text,
            citations: citations,
            timestamp: Date()
        )
    }
}
