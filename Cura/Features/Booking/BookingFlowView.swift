import SwiftUI

// MARK: - Booking Step

enum BookingStep: Int, CaseIterable {
    case selectLovedOne     = 1
    case selectCareType     = 2
    case selectSchedule     = 3
    case selectTasks        = 4
    case selectCaregiver    = 5
    case addInstructions    = 6
    case reviewPricing      = 7
    case confirmPayment     = 8
    case bookingConfirmed   = 9

    var title: String {
        switch self {
        case .selectLovedOne:   return "Who needs care?"
        case .selectCareType:   return "Type of care"
        case .selectSchedule:   return "When?"
        case .selectTasks:      return "Care tasks"
        case .selectCaregiver:  return "Choose a caregiver"
        case .addInstructions:  return "Instructions"
        case .reviewPricing:    return "Review & pricing"
        case .confirmPayment:   return "Payment"
        case .bookingConfirmed: return "Confirmed!"
        }
    }
}

// MARK: - Care Type

private struct CareType: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
}

private let allCareTypes: [CareType] = [
    CareType(emoji: "👥", name: "Companionship"),
    CareType(emoji: "🧩", name: "Dementia Routine Support"),
    CareType(emoji: "🍽", name: "Meal & Hydration"),
    CareType(emoji: "💊", name: "Medication Reminders"),
    CareType(emoji: "🛁", name: "Personal Care"),
    CareType(emoji: "🚶", name: "Mobility Assistance"),
    CareType(emoji: "🌙", name: "Evening Support"),
    CareType(emoji: "⭐", name: "Overnight Support"),
    CareType(emoji: "☕", name: "Respite Care"),
    CareType(emoji: "🏥", name: "Hospital Attendant"),
    CareType(emoji: "🕊", name: "Hospice & Comfort Support"),
    CareType(emoji: "🆘", name: "Emergency Replacement"),
]

// MARK: - Booking ViewModel

@MainActor
@Observable
final class BookingFlowViewModel {
    var currentStep: BookingStep = .selectLovedOne
    var selectedLovedOne: LovedOne? = nil
    var selectedCareType: CareType? = nil
    var selectedDate: Date = Date()
    var selectedStartTime: Date = Date()
    var durationHours: Double = 4
    var isRecurring: Bool = false
    var selectedTasks: Set<UUID> = []
    var availableTasks: [BookingTask] = SampleData.activeBooking.tasks
    var customTask: String = ""
    var selectedCaregiver: Caregiver? = nil
    var instructions: String = "Please follow the care passport for routines. Knock before entering. Use Marathi when possible."
    var paymentMethod: String = "Visa •••• 4242"
    var confirmedBooking: Booking? = nil

    var progressFraction: Double {
        Double(currentStep.rawValue) / Double(BookingStep.allCases.count)
    }

    var hourlyRate: Double { 35.00 }
    var platformFee: Double { hourlyRate * durationHours * 0.12 }
    var taxes: Double { (hourlyRate * durationHours + platformFee) * 0.05 }
    var total: Double { hourlyRate * durationHours + platformFee + taxes }

    func advanceStep() {
        guard let next = BookingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = next }
    }

    func goBack() {
        guard let prev = BookingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep = prev }
    }

    func confirmBooking() async {
        // Mock confirmation — in production calls container.bookingService.createBooking(...)
        try? await Task.sleep(nanoseconds: 800_000_000)
        confirmedBooking = SampleData.activeBooking
        advanceStep()
    }
}

// MARK: - BookingFlowView

struct BookingFlowView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = BookingFlowViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.currentStep != .bookingConfirmed {
                    progressBar
                }
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.currentStep != .bookingConfirmed && viewModel.currentStep != .selectLovedOne {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.currentStep != .bookingConfirmed {
                        Button("Cancel") { dismiss() }
                            .font(.careBody)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.careAccentBlue.opacity(0.15))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.careAccentBlue)
                    .frame(width: geo.size.width * viewModel.progressFraction, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progressFraction)
            }
        }
        .frame(height: 3)
    }

    // MARK: Step Router

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .selectLovedOne:   selectLovedOneStep
        case .selectCareType:   selectCareTypeStep
        case .selectSchedule:   selectScheduleStep
        case .selectTasks:      selectTasksStep
        case .selectCaregiver:  selectCaregiverStep
        case .addInstructions:  addInstructionsStep
        case .reviewPricing:    reviewPricingStep
        case .confirmPayment:   confirmPaymentStep
        case .bookingConfirmed: bookingConfirmedStep
        }
    }

    // MARK: Step 1 — Select Loved One

    private var selectLovedOneStep: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Text("Select who needs care")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                lovedOneCard(SampleData.lovedOne)

                Spacer(minLength: Spacing.xl)
            }
        }
    }

    private func lovedOneCard(_ person: LovedOne) -> some View {
        Button {
            viewModel.selectedLovedOne = person
            viewModel.availableTasks = SampleData.activeBooking.tasks
            viewModel.advanceStep()
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.careAccentTeal.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Text(String(person.name.prefix(1)))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.careAccentTeal)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(person.name)
                        .font(.careHeading)
                        .foregroundStyle(.textPrimary)
                    Text(person.primaryCondition ?? "No condition listed")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Image(systemName: viewModel.selectedLovedOne?.id == person.id ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(viewModel.selectedLovedOne?.id == person.id ? Color.careAccentBlue : Color.textSecondary)
            }
            .padding(Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(viewModel.selectedLovedOne?.id == person.id ? Color.careAccentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: Step 2 — Care Type

    private var selectCareTypeStep: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(allCareTypes) { type in
                    careTypeCell(type)
                }
            }
            .padding(Spacing.md)

            continueButton(enabled: viewModel.selectedCareType != nil) {
                viewModel.advanceStep()
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func careTypeCell(_ type: CareType) -> some View {
        let isSelected = viewModel.selectedCareType?.id == type.id
        return Button {
            viewModel.selectedCareType = type
        } label: {
            VStack(spacing: Spacing.sm) {
                Text(type.emoji)
                    .font(.system(size: 36))
                Text(type.name)
                    .font(.careCaption)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(Spacing.sm)
            .background(isSelected ? Color.careAccentBlue.opacity(0.10) : Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(isSelected ? Color.careAccentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: Step 3 — Schedule

    private var selectScheduleStep: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                CareCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Date").font(.careBodyMedium).foregroundStyle(.textPrimary)
                        DatePicker("Select date", selection: $viewModel.selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.careAccentBlue)
                    }
                    .padding(Spacing.md)
                }

                CareCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Start time").font(.careBodyMedium).foregroundStyle(.textPrimary)
                        DatePicker("Start time", selection: $viewModel.selectedStartTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .tint(.careAccentBlue)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(Spacing.md)
                }

                CareCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text("Duration").font(.careBodyMedium).foregroundStyle(.textPrimary)
                            Spacer()
                            Text("\(Int(viewModel.durationHours)) hr\(viewModel.durationHours == 1 ? "" : "s")")
                                .font(.careBodyMedium)
                                .foregroundStyle(.careAccentBlue)
                        }
                        Slider(value: $viewModel.durationHours, in: 1...12, step: 1)
                            .tint(.careAccentBlue)
                    }
                    .padding(Spacing.md)
                }

                CareCard {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Recurring").font(.careBodyMedium).foregroundStyle(.textPrimary)
                            Text("Repeat on a regular schedule").font(.careCaption).foregroundStyle(.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.isRecurring)
                            .tint(.careAccentBlue)
                    }
                    .padding(Spacing.md)
                }

                continueButton(enabled: true) { viewModel.advanceStep() }
                    .padding(.horizontal, Spacing.md)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: Step 4 — Tasks

    private var selectTasksStep: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Text("Select care tasks for this visit")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.availableTasks) { task in
                    taskCheckRow(task)
                }

                addCustomTaskRow

                continueButton(enabled: !viewModel.selectedTasks.isEmpty) {
                    viewModel.advanceStep()
                }
            }
            .padding(Spacing.md)
        }
    }

    private func taskCheckRow(_ task: BookingTask) -> some View {
        let isChecked = viewModel.selectedTasks.contains(task.id)
        return Button {
            if isChecked {
                viewModel.selectedTasks.remove(task.id)
            } else {
                viewModel.selectedTasks.insert(task.id)
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? Color.careAccentBlue : Color.textSecondary)
                    .font(.title3)
                    .frame(width: 28, height: 28)
                Text(task.title)
                    .font(.careBody)
                    .foregroundStyle(.textPrimary)
                Spacer()
            }
            .padding(Spacing.sm)
            .background(isChecked ? Color.careAccentBlue.opacity(0.06) : Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isChecked)
    }

    private var addCustomTaskRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.careAccentBlue)
                .font(.title3)
                .frame(width: 28, height: 28)
            TextField("Add a custom task", text: $viewModel.customTask)
                .font(.careBody)
                .onSubmit {
                    guard !viewModel.customTask.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let newTask = BookingTask(
                        id: UUID(),
                        title: viewModel.customTask,
                        isCompleted: false,
                        notes: nil
                    )
                    viewModel.availableTasks.append(newTask)
                    viewModel.selectedTasks.insert(newTask.id)
                    viewModel.customTask = ""
                }
        }
        .padding(Spacing.sm)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: Step 5 — Caregiver

    private var selectCaregiverStep: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Text("3 caregivers match your needs")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(SampleData.caregivers.prefix(3)) { caregiver in
                    caregiverSelectionCard(caregiver)
                }

                Button("See all available caregivers") { }
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.sm)

                continueButton(enabled: viewModel.selectedCaregiver != nil) {
                    viewModel.advanceStep()
                }
            }
            .padding(Spacing.md)
        }
    }

    private func caregiverSelectionCard(_ caregiver: Caregiver) -> some View {
        let isSelected = viewModel.selectedCaregiver?.id == caregiver.id
        return Button {
            viewModel.selectedCaregiver = caregiver
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.careAccentBlue.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Text(String(caregiver.name.prefix(1)))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.careAccentBlue)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(caregiver.name)
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.careAttention)
                            Text(String(format: "%.1f", caregiver.rating))
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                            Text("·")
                                .foregroundStyle(.textSecondary)
                            Text(caregiver.primaryLanguage)
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.careAccentBlue)
                            .font(.title3)
                    }
                }

                Text(caregiverMatchReason(caregiver))
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.careAccentTeal.opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(Spacing.md)
            .background(isSelected ? Color.careAccentBlue.opacity(0.06) : Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(isSelected ? Color.careAccentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func caregiverMatchReason(_ caregiver: Caregiver) -> String {
        let reasons = [
            "Speaks Marathi · 3 years dementia care experience",
            "Has cared for similar conditions · Available this weekend",
            "Top rated in your area · Familiar with Mumbai routines",
        ]
        return reasons[min(SampleData.caregivers.firstIndex(where: { $0.id == caregiver.id }) ?? 0, reasons.count - 1)]
    }

    // MARK: Step 6 — Instructions

    private var addInstructionsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Standing care instructions")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)

                TextEditor(text: $viewModel.instructions)
                    .font(.careBody)
                    .frame(minHeight: 150)
                    .padding(Spacing.sm)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.careAccentBlue)
                    Text("This will be translated for the caregiver.")
                        .font(.careCaption)
                        .foregroundStyle(.careAccentBlue)
                }

                continueButton(enabled: true) { viewModel.advanceStep() }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: Step 7 — Pricing

    private var reviewPricingStep: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                CareCard {
                    VStack(spacing: Spacing.sm) {
                        pricingRow(
                            label: "Hourly rate × \(Int(viewModel.durationHours)) hr\(viewModel.durationHours == 1 ? "" : "s")",
                            value: String(format: "₹%.2f", viewModel.hourlyRate * viewModel.durationHours * 83)
                        )
                        pricingRow(label: "Platform fee (12%)", value: String(format: "₹%.2f", viewModel.platformFee * 83))
                        pricingRow(label: "GST (5%)", value: String(format: "₹%.2f", viewModel.taxes * 83))
                        Divider()
                        HStack {
                            Text("Total")
                                .font(.careHeading)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text(String(format: "₹%.0f", viewModel.total * 83))
                                .font(.careHeading)
                                .foregroundStyle(.careAccentBlue)
                        }
                    }
                    .padding(Spacing.md)
                }

                CareCard {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.textSecondary)
                            .font(.body)
                        Text("Free cancellation up to 24 hours before the visit. Cancellations within 24 hours may incur a fee of up to 50% of the booking value.")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.md)
                }

                continueButton(enabled: true) { viewModel.advanceStep() }
                    .padding(.horizontal, Spacing.md)
            }
            .padding(Spacing.md)
        }
    }

    private func pricingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.careBody)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(value)
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
        }
    }

    // MARK: Step 8 — Payment

    private var confirmPaymentStep: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Apple Pay
                Button {
                    // Apple Pay placeholder
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "apple.logo")
                            .font(.title3.weight(.semibold))
                        Text("Pay with Apple Pay")
                            .font(.careBodyMedium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                }

                // Saved payment method
                CareCard {
                    HStack(spacing: Spacing.md) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.careAccentBlue.opacity(0.15))
                            .frame(width: 44, height: 30)
                            .overlay(
                                Text("VISA")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Color.careAccentBlue)
                            )
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Visa ending 4242")
                                .font(.careBodyMedium)
                                .foregroundStyle(.textPrimary)
                            Text("Expires 12/27")
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                        Spacer()
                        Button("Use") {
                            Task { await viewModel.confirmBooking() }
                        }
                        .font(.careBodyMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.careAccentBlue)
                        .clipShape(Capsule())
                    }
                    .padding(Spacing.md)
                }

                // Security note
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                    Text("Secure payment — encrypted end-to-end.")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: Step 9 — Confirmed

    private var bookingConfirmedStep: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Spacer(minLength: Spacing.xl)

                // Success illustration
                ZStack {
                    Circle()
                        .fill(Color.carePositive.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.carePositive)
                }

                VStack(spacing: Spacing.sm) {
                    Text("Booking Confirmed!")
                        .font(.careDisplayMedium)
                        .foregroundStyle(.textPrimary)
                    Text("Your care is scheduled and the caregiver has been notified.")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Summary card
                CareCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let caregiver = viewModel.selectedCaregiver {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.careAccentBlue)
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(caregiver.name)
                                        .font(.careBodyMedium)
                                        .foregroundStyle(.textPrimary)
                                    Text("Caregiver confirmed")
                                        .font(.careCaption)
                                        .foregroundStyle(.textSecondary)
                                }
                            }
                        }

                        Divider()

                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "calendar")
                                .foregroundStyle(.careAccentTeal)
                                .font(.body)
                                .frame(width: 24)
                            Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).month().day())
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                        }

                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "clock")
                                .foregroundStyle(.careAccentTeal)
                                .font(.body)
                                .frame(width: 24)
                            Text("\(viewModel.selectedStartTime, format: .dateTime.hour().minute()) · \(Int(viewModel.durationHours)) hrs")
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                        }

                        Divider()

                        Text("What happens next:")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            nextStep(num: "1", text: "Caregiver will review the care passport")
                            nextStep(num: "2", text: "You'll get a reminder 2 hrs before the visit")
                            nextStep(num: "3", text: "Track the visit live in the Timeline tab")
                        }
                    }
                    .padding(Spacing.md)
                }

                VStack(spacing: Spacing.sm) {
                    PrimaryButton(title: "View Booking") { }

                    Button("Go Home") { dismiss() }
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
            }
            .padding(Spacing.md)
        }
    }

    private func nextStep(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(num)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.careAccentBlue)
                .clipShape(Circle())
            Text(text)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    // MARK: Continue Button Helper

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        PrimaryButton(title: "Continue", isDisabled: !enabled, action: action)
    }
}

// MARK: - Preview

#Preview {
    BookingFlowView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
