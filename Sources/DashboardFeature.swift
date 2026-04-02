// DashboardFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Dashboard: greeting, daily session, up-next tasks, activity insights, timeline.

import SwiftUI

// MARK: - Dashboard ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var upNextTasks:      [TaskItem]     = []
    @Published private(set) var todayEvents:      [CalendarEvent] = []
    @Published private(set) var completedCount:   Int             = 0
    @Published private(set) var totalCount:       Int             = 0
    @Published private(set) var productivityScore: Int            = 0
    @Published private(set) var deepWorkCount:    Int             = 0
    @Published private(set) var state: LoadingState<Bool>        = .idle

    private let taskRepository:  TaskRepositoryProtocol
    private let eventRepository: CalendarEventRepositoryProtocol

    init(
        taskRepository:  TaskRepositoryProtocol,
        eventRepository: CalendarEventRepositoryProtocol
    ) {
        self.taskRepository  = taskRepository
        self.eventRepository = eventRepository
    }

    deinit {
        #if DEBUG
        print("DashboardViewModel deinitialized")
        #endif
    }

    // MARK: - Computed

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default:      return "Good Evening"
        }
    }

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, Double(completedCount) / Double(totalCount))
    }

    var activeTaskCount: Int { max(0, totalCount - completedCount) }

    // MARK: - Load

    func load() async {
        state = .loading
        do {
            async let tasks  = taskRepository.fetchAll()
            async let events = eventRepository.fetchEventsForDay(.now)

            let allTasks    = try await tasks
            let todayEvents = try await events

            let calendar  = Calendar.current
            let completed = allTasks.filter { $0.isCompleted }

            self.upNextTasks    = Array(allTasks.filter { !$0.isCompleted }.prefix(3))
            self.completedCount = completed.count
            self.totalCount     = allTasks.count
            self.todayEvents    = todayEvents

            // Productivity score: completion rate mapped to 10–100
            let rate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
            self.productivityScore = max(10, min(100, Int(rate * 90) + 10))

            // Deep work tasks completed today
            self.deepWorkCount = completed.filter { task in
                task.category == .deepWork &&
                task.completedDate.map { calendar.isDateInToday($0) } == true
            }.count

            state = .loaded(true)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        // Greeting
                        greetingSection
                            .padding(.top, DesignTokens.Spacing.sm)

                        // Today's Session card
                        sessionCard

                        // Up Next
                        upNextSection

                        // Activity Insights
                        insightsSection

                        // Timeline
                        if !viewModel.todayEvents.isEmpty {
                            timelineSection
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Productivity", showSearch: true) {
                        isSearching = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(viewModel.greeting + ",")
                .font(.title3.weight(.medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text("Alexander.")
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Session Card

    private var sessionCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("TODAY'S SESSION")
                        .sectionLabel()
                    Spacer()
                }
                .padding(.bottom, DesignTokens.Spacing.sm)

                Text("Daily Objective")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(sessionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.top, 2)
                    .padding(.bottom, DesignTokens.Spacing.md)

                HStack(alignment: .center) {
                    Button {
                        // Resume/start focus session
                    } label: {
                        Text("Resume Session")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(DesignTokens.Colors.accent, in: Capsule())
                    }
                    .accessibilityLabel("Resume today's session")

                    Spacer()

                    DSProgressRing(
                        progress: viewModel.progressFraction,
                        size: 64,
                        lineWidth: 7
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var sessionSubtitle: String {
        let active = viewModel.activeTaskCount
        let done   = viewModel.completedCount
        if active == 0 && done == 0 {
            return "No tasks yet. Add one to get started."
        } else if active == 0 {
            return "All \(done) tasks complete. Great work!"
        } else {
            return "You have completed \(done) of \(viewModel.totalCount) key tasks for today."
        }
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Up Next")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Button("View All Tasks") {}
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.accent)
                    .accessibilityLabel("View all tasks")
            }

            if viewModel.upNextTasks.isEmpty {
                DSCard {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.success)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(viewModel.upNextTasks, id: \.id) { task in
                        UpNextTaskRow(task: task)
                    }
                }
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Activity Insights")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            HStack(spacing: DesignTokens.Spacing.md) {
                DSStatCard(
                    icon: "chart.bar.fill",
                    iconColor: DesignTokens.Colors.accent,
                    value: "\(viewModel.productivityScore)/100",
                    label: "Productivity Score"
                )

                DSStatCard(
                    icon: "brain.head.profile",
                    iconColor: DesignTokens.Colors.warning,
                    value: String(format: "%.1fh", Double(viewModel.deepWorkCount) * 1.5),
                    label: "Deep Work Hours"
                )
            }
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Timeline")
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(viewModel.todayEvents.prefix(3), id: \.id) { event in
                    TimelineEventRow(event: event)
                }
            }
        }
    }
}

// MARK: - Up Next Task Row

private struct UpNextTaskRow: View {
    let task: TaskItem

    var body: some View {
        DSCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Priority color strip
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.priorityColor(task.priority))
                    .frame(width: 3)
                    .padding(.vertical, DesignTokens.Spacing.xs)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        DSWorkspaceBadge(workspace: task.workspace)
                        if let due = task.dueDate {
                            Text(due.relativeDisplay)
                                .font(.caption)
                                .foregroundStyle(
                                    due.isOverdue
                                        ? DesignTokens.Colors.destructive
                                        : DesignTokens.Colors.textTertiary
                                )
                        }
                    }
                }

                Spacer()

                DSPriorityDot(priority: task.priority, size: 8)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.priority.label) priority, \(task.workspace.rawValue)")
    }
}

// MARK: - Timeline Event Row

private struct TimelineEventRow: View {
    let event: CalendarEvent

    var body: some View {
        DSCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.fromHex(event.colorHex))
                    .frame(width: 3)
                    .padding(.vertical, DesignTokens.Spacing.xs)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    Text(event.startDate.timeFormatted)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                Text("\(event.durationMinutes)m")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title) at \(event.startDate.timeFormatted)")
    }
}
