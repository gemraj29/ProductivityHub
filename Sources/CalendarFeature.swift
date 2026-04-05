// CalendarFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Calendar hub with custom month grid, selected-day agenda, and event creation.
// Design: matches Stitch calendar_view/code.html exactly.

import SwiftUI

// MARK: - Calendar Hub ViewModel

@MainActor
final class CalendarHubViewModel: ObservableObject {
    @Published var selectedDate:             Date           = .now
    @Published private(set) var eventsForSelectedDay: [CalendarEvent] = []
    @Published private(set) var allEventsThisMonth:   [CalendarEvent] = []
    @Published private(set) var state: LoadingState<[CalendarEvent]>  = .idle

    private let eventRepository:     CalendarEventRepositoryProtocol
    private let notificationService: NotificationServiceProtocol

    init(
        eventRepository:     CalendarEventRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.eventRepository     = eventRepository
        self.notificationService = notificationService
    }

    deinit {
        #if DEBUG
        print("CalendarHubViewModel deinitialized")
        #endif
    }

    var currentMonthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d"
        return formatter.string(from: selectedDate)
    }

    var monthTaskCount: Int { allEventsThisMonth.count }

    func datesWithEvents() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(allEventsThisMonth.map { formatter.string(from: $0.startDate) })
    }

    func hasEvent(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return datesWithEvents().contains(formatter.string(from: date))
    }

    func hasHighPriorityEvent(on date: Date) -> Bool {
        let cal = Calendar.current
        return allEventsThisMonth.contains { cal.isDate($0.startDate, inSameDayAs: date) && $0.colorHex == "#852205" }
    }

    func load() async {
        state = .loading
        do {
            eventsForSelectedDay = try eventRepository.fetchEventsForDay(selectedDate)

            let calendar = Calendar.current
            guard
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else {
                state = .loaded(eventsForSelectedDay)
                return
            }
            allEventsThisMonth = try eventRepository.fetchEvents(from: monthStart, to: monthEnd)
            state = .loaded(eventsForSelectedDay)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func selectDate(_ date: Date) async {
        selectedDate = date
        await load()
    }

    func stepMonth(by delta: Int) async {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: delta, to: selectedDate) {
            selectedDate = newDate
            await load()
        }
    }

    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try eventRepository.delete(event)
            await load()
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func createEvent(
        title: String,
        description: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        colorHex: String
    ) async throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validationFailed("Event title cannot be empty.")
        }
        guard endDate > startDate else {
            throw AppError.validationFailed("End time must be after start time.")
        }
        let event = CalendarEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            colorHex: colorHex
        )
        try eventRepository.insert(event)
        await load()
    }
}

// MARK: - Calendar Hub View (Stitch layout)

struct CalendarHubView: View {
    @ObservedObject var viewModel: CalendarHubViewModel
    @State private var showingNewEvent = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                            // Calendar grid (dominant)
                            monthCalendarCard
                                .frame(maxWidth: .infinity)

                            // Agenda sidebar
                            agendaPanel
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity", showSearch: false)
                        .frame(maxWidth: .infinity)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignTokens.Colors.primary)
                    }
                    .accessibilityLabel("Add new event")
                }
            }
            .sheet(isPresented: $showingNewEvent) { Task { await viewModel.load() } } content: {
                EventCreationSheet(
                    initialDate: viewModel.selectedDate,
                    onSave: { title, desc, start, end, allDay, color in
                        try await viewModel.createEvent(
                            title: title, description: desc,
                            startDate: start, endDate: end,
                            isAllDay: allDay, colorHex: color
                        )
                    }
                )
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Month Calendar Card

    private var monthCalendarCard: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header: month title + nav arrows
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentMonthTitle)
                        .font(.headline(22))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("\(viewModel.monthTaskCount) tasks scheduled this month")
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                Spacer()
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button { Task { await viewModel.stepMonth(by: -1) } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.primary)
                            .frame(width: 38, height: 38)
                            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .shadow(color: Color(hex: "#00334d").opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .accessibilityLabel("Previous month")

                    Button { Task { await viewModel.stepMonth(by: 1) } } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.primary)
                            .frame(width: 38, height: 38)
                            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .shadow(color: Color(hex: "#00334d").opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .accessibilityLabel("Next month")
                }
            }

            // Day-of-week headers
            let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            HStack(spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { day in
                    Text(day.uppercased())
                        .font(.label(10, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.onSecondaryFixedVariant)
                        .kerning(0.5)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date cells
            let days = calendarDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    CalendarDayCell(
                        date: date,
                        isSelected: date.map { Calendar.current.isDate($0, inSameDayAs: viewModel.selectedDate) } ?? false,
                        isToday: date.map { Calendar.current.isDateInToday($0) } ?? false,
                        hasEvent: date.map { viewModel.hasEvent(on: $0) } ?? false,
                        hasHighPriority: date.map { viewModel.hasHighPriorityEvent(on: $0) } ?? false,
                        onTap: { if let d = date { Task { await viewModel.selectDate(d) } } }
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
    }

    // MARK: - Agenda Panel

    private var agendaPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text(viewModel.selectedDayTitle)
                    .font(.headline(18))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Button {
                    showingNewEvent = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New Task")
                            .font(.body(13, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.Colors.primary)
                }
                .accessibilityLabel("Add new event for this day")
            }

            if viewModel.eventsForSelectedDay.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(DesignTokens.Colors.primaryFixed)
                    Text("No events scheduled")
                        .font(.body(13))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xl)
            } else {
                // Timeline of events
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Vertical connector line
                    ForEach(Array(viewModel.eventsForSelectedDay.enumerated()), id: \.element.id) { index, event in
                        AgendaEventRow(event: event)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteEvent(event) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
    }

    // MARK: - Calendar Days Helper

    private func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.selectedDate)),
            let monthRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        // Weekday of first day (Mon-based: Mon=0 … Sun=6)
        let rawWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (rawWeekday + 5) % 7  // convert Sun=1…Sat=7 to Mon=0…Sun=6

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        // Pad to complete last row
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date:            Date?
    let isSelected:      Bool
    let isToday:         Bool
    let hasEvent:        Bool
    let hasHighPriority: Bool
    let onTap:           () -> Void

    var body: some View {
        Button(action: onTap) {
            cellContent
                .padding(DesignTokens.Spacing.sm)
                .frame(height: 64)
                .background(cellBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
                .shadow(color: cellShadowColor, radius: cellShadowRadius, x: 0, y: cellShadowY)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                .opacity(date == nil ? 0 : 1)
        }
        .buttonStyle(.plain)
        .disabled(date == nil)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var cellContent: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if let date {
                dayNumberText(for: date)
                Spacer(minLength: 0)
                eventDots
            }
        }
    }

    private func dayNumberText(for date: Date) -> some View {
        let day = Calendar.current.component(.day, from: date)
        let fontWeight: Font.Weight = isSelected ? .bold : .semibold
        let foreground: Color = isSelected ? Color.white : DesignTokens.Colors.textPrimary
        return Text("\(day)")
            .font(.headline(15, weight: fontWeight))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventDots: some View {
        HStack(spacing: 3) {
            if hasEvent {
                let dotColor: Color = isSelected ? Color.white : DesignTokens.Colors.primary
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
            }
            if hasHighPriority {
                let highDotColor: Color = isSelected ? Color.white.opacity(0.7) : DesignTokens.Colors.tertiaryContainer
                Circle()
                    .fill(highDotColor)
                    .frame(width: 5, height: 5)
            }
        }
    }

    // MARK: - Computed style helpers

    private var cellBackground: AnyShapeStyle {
        if isSelected {
            AnyShapeStyle(LinearGradient.deepSeaPrimary)
        } else {
            AnyShapeStyle(DesignTokens.Colors.backgroundCard)
        }
    }

    private var cellShadowColor: Color {
        isSelected ? DesignTokens.Colors.primary.opacity(0.3) : Color(hex: "#00334d").opacity(0.04)
    }

    private var cellShadowRadius: CGFloat { isSelected ? 10 : 4 }
    private var cellShadowY: CGFloat { isSelected ? 4 : 1 }

    private var accessibilityText: String {
        guard let date else { return "" }
        return "\(Calendar.current.component(.day, from: date))"
    }
}

// MARK: - Agenda Event Row (Stitch timeline style)

struct AgendaEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // Timeline dot
            Circle()
                .fill(DesignTokens.Colors.primary)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Time range
                HStack {
                    Text(event.isAllDay ? "All Day" : "\(event.startDate.timeFormatted) — \(event.endDate.timeFormatted)")
                        .font(.label(10, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .kerning(0.5)
                    Spacer()
                    // Priority-style badge based on colorHex
                    priorityBadge
                }

                Text(event.title)
                    .font(.headline(15))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.body(13))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
            .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title) at \(event.startDate.timeFormatted)")
    }

    private var priorityBadge: some View {
        let text: String
        let bg: Color
        let fg: Color
        switch event.colorHex.lowercased() {
        case "#852205":
            text = "HIGH"
            bg = DesignTokens.Colors.tertiaryContainer
            fg = Color.white
        case "#5e5ce6", "#0a84ff":
            text = "LOW"
            bg = DesignTokens.Colors.primaryFixed
            fg = DesignTokens.Colors.onPrimaryFixed
        default:
            text = "MED"
            bg = DesignTokens.Colors.secondaryContainer
            fg = DesignTokens.Colors.onSecondaryFixedVariant
        }
        return Text(text)
            .font(.label(9, weight: .bold))
            .foregroundStyle(fg)
            .kerning(0.5)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 3)
            .background(bg, in: Capsule())
    }
}

// MARK: - Event Row (compact, used elsewhere)

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(.body(14, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if event.isAllDay {
                    Text("All Day")
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                } else {
                    Text("\(event.startDate.timeFormatted) – \(event.endDate.timeFormatted)")
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if event.durationMinutes > 0 && !event.isAllDay {
                Text("\(event.durationMinutes)m")
                    .font(.label(11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(DesignTokens.Colors.surfaceHigh, in: Capsule())
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Event Creation Sheet

struct EventCreationSheet: View {
    let initialDate: Date
    let onSave: (String, String, Date, Date, Bool, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title             = ""
    @State private var description       = ""
    @State private var startDate:        Date
    @State private var endDate:          Date
    @State private var isAllDay          = false
    @State private var selectedColorHex  = "#00334d"
    @State private var showError         = false
    @State private var errorMessage      = ""
    @State private var isSaving          = false

    private let colorOptions = [
        "#00334d", "#004b6e", "#852205", "#601200",
        "#30D158", "#FF453A", "#FF9F0A", "#5E5CE6"
    ]

    init(
        initialDate: Date,
        onSave: @escaping (String, String, Date, Date, Bool, String) async throws -> Void
    ) {
        self.initialDate = initialDate
        self.onSave = onSave
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        _startDate = State(initialValue: start)
        _endDate   = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                        .font(.headline(16))
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Time") {
                    Toggle("All Day", isOn: $isAllDay.animation())
                        .tint(DesignTokens.Colors.primary)

                    if isAllDay {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("Start", selection: $startDate)
                        DatePicker("End",   selection: $endDate, in: startDate...)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if hex == selectedColorHex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { selectedColorHex = hex }
                                .accessibilityLabel("Color option")
                                .accessibilityAddTraits(hex == selectedColorHex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do {
                                let effectiveEnd = isAllDay
                                    ? (Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate)
                                    : endDate
                                try await onSave(title, description, startDate, effectiveEnd, isAllDay, selectedColorHex)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}

extension CalendarEvent: Identifiable {}
