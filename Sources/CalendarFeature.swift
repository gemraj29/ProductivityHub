// CalendarFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Calendar hub with month view, day detail, and event creation.

import SwiftUI

// MARK: - Calendar Hub ViewModel

@MainActor
final class CalendarHubViewModel: ObservableObject {
    @Published var selectedDate: Date = .now
    @Published private(set) var eventsForSelectedDay: [CalendarEvent] = []
    @Published private(set) var allEventsThisMonth: [CalendarEvent] = []
    @Published private(set) var state: LoadingState<[CalendarEvent]> = .idle

    private let eventRepository: CalendarEventRepositoryProtocol
    private let notificationService: NotificationServiceProtocol

    init(
        eventRepository: CalendarEventRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.eventRepository = eventRepository
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

    func datesWithEvents() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(allEventsThisMonth.map { formatter.string(from: $0.startDate) })
    }

    func load() async {
        state = .loading
        do {
            eventsForSelectedDay = try eventRepository.fetchEventsForDay(selectedDate)

            let calendar = Calendar.current
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
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

// MARK: - Calendar Hub View

struct CalendarHubView: View {
    @ObservedObject var viewModel: CalendarHubViewModel
    @State private var showingNewEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Calendar
                DatePicker(
                    "Select Date",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                #if compiler(>=5.9)
                .onChange(of: viewModel.selectedDate) { _, newDate in
                    Task { await viewModel.selectDate(newDate) }
                }
                #else
                .onChange(of: viewModel.selectedDate) { newDate in
                    Task { await viewModel.selectDate(newDate) }
                }
                #endif

                Divider()

                // Day's Events
                dayEventsSection
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add new event")
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task { await viewModel.selectDate(.now) }
                    } label: {
                        Text("Today")
                    }
                    .accessibilityLabel("Go to today")
                }
            }
            .sheet(isPresented: $showingNewEvent) {
                Task { await viewModel.load() }
            } content: {
                EventCreationSheet(
                    initialDate: viewModel.selectedDate,
                    onSave: { title, desc, start, end, allDay, color in
                        try await viewModel.createEvent(
                            title: title,
                            description: desc,
                            startDate: start,
                            endDate: end,
                            isAllDay: allDay,
                            colorHex: color
                        )
                    }
                )
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Day Events Section

    @ViewBuilder
    private var dayEventsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(viewModel.selectedDate.shortFormatted)
                    .sectionHeader()

                Spacer()

                Text("\(viewModel.eventsForSelectedDay.count) events")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.md)

            if viewModel.eventsForSelectedDay.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                    Text("No events scheduled")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, DesignTokens.Spacing.xxxl)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(viewModel.eventsForSelectedDay, id: \.id) { event in
                            EventRowView(event: event)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteEvent(event) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - Event Row

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.Colors.fromHex(event.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if event.isAllDay {
                    Text("All Day")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                } else {
                    Text("\(event.startDate.timeFormatted) – \(event.endDate.timeFormatted)")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if event.durationMinutes > 0 && !event.isAllDay {
                Text("\(event.durationMinutes)m")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(
                        DesignTokens.Colors.surfaceSecondary,
                        in: Capsule()
                    )
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            DesignTokens.Colors.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Event Creation Sheet

struct EventCreationSheet: View {
    let initialDate: Date
    let onSave: (String, String, Date, Date, Bool, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var selectedColorHex = "#5E5CE6"
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    private let colorOptions = [
        "#5E5CE6", "#FF453A", "#FF9F0A", "#30D158",
        "#0A84FF", "#BF5AF2", "#FF6482", "#64D2FF"
    ]

    init(initialDate: Date, onSave: @escaping (String, String, Date, Date, Bool, String) async throws -> Void) {
        self.initialDate = initialDate
        self.onSave = onSave
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                        .font(.headline)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Time") {
                    Toggle("All Day", isOn: $isAllDay.animation())

                    if isAllDay {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("Start", selection: $startDate)
                        DatePicker("End", selection: $endDate, in: startDate...)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(DesignTokens.Colors.fromHex(hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if hex == selectedColorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
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
                                    ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate
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
