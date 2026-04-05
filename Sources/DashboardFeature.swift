// DashboardFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Dashboard: greeting, daily session hero, up-next tasks, activity insights, timeline.
// Design: matches Stitch dashboard/code.html exactly.

import SwiftUI

// MARK: - Dashboard ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var upNextTasks:       [TaskItem]      = []
    @Published private(set) var todayEvents:       [CalendarEvent] = []
    @Published private(set) var completedCount:    Int             = 0
    @Published private(set) var totalCount:        Int             = 0
    @Published private(set) var productivityScore: Int             = 0
    @Published private(set) var deepWorkHours:     Double          = 0
    @Published private(set) var state: LoadingState<Bool>          = .idle

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

    // MARK: Computed

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

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: .now)
    }

    // MARK: Load

    func load() async {
        state = .loading
        do {
            async let tasks  = taskRepository.fetchAll()
            async let events = eventRepository.fetchEventsForDay(.now)

            let allTasks    = try await tasks
            let dailyEvents = try await events

            let calendar  = Calendar.current
            let completed = allTasks.filter { $0.isCompleted }

            self.upNextTasks    = Array(allTasks.filter { !$0.isCompleted }.prefix(3))
            self.completedCount = completed.count
            self.totalCount     = allTasks.count
            self.todayEvents    = dailyEvents

            let rate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
            self.productivityScore = max(10, min(100, Int(rate * 90) + 10))

            let deepWorkDone = completed.filter { task in
                task.category == .deepWork &&
                task.completedDate.map { calendar.isDateInToday($0) } == true
            }.count
            self.deepWorkHours = Double(deepWorkDone) * 1.5

            state = .loaded(true)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @AppStorage("userName") private var userName: String = "Alexander"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.xl) {
                        greetingSection
                            .padding(.top, DesignTokens.Spacing.sm)

                        sessionHeroCard

                        upNextSection

                        insightsSidebarCard

                        if !viewModel.todayEvents.isEmpty {
                            timelineSection
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity", showSearch: true)
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
            Text(viewModel.dateLabel.uppercased())
                .font(.label(11, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .kerning(1.2)
            Text("\(viewModel.greeting), \(userName).")
                .font(.headline(30))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Session Hero Card (the big bento card with progress ring)

    private var sessionHeroCard: some View {
        ZStack {
            // Background decorative glow
            Circle()
                .fill(DesignTokens.Colors.primaryContainer.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 30, y: -30)

            HStack(alignment: .center, spacing: DesignTokens.Spacing.xl) {
                // Left content
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    // Focus session pill
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.onPrimaryFixed)
                        Text("FOCUS SESSION")
                            .font(.label(10, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.onPrimaryFixed)
                            .kerning(0.8)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.primaryFixed, in: Capsule())

                    Text("Daily Objective")
                        .font(.headline(20))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(sessionSubtitle)
                        .font(.body(14))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        // Resume focus session — navigates to Focus tab via parent
                    } label: {
                        Text("Resume Session")
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.onPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.vertical, DesignTokens.Spacing.sm + 2)
                            .background(LinearGradient.deepSeaPrimary, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
                    }
                    .accessibilityLabel("Resume today's focus session")
                }

                Spacer(minLength: 0)

                // Progress ring
                DSProgressRing(
                    progress: viewModel.progressFraction,
                    size: 110,
                    lineWidth: 10
                )
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
        .shadow(color: Color(hex: "#00334d").opacity(0.08), radius: 24, x: 0, y: 8)
    }

    private var sessionSubtitle: String {
        let done   = viewModel.completedCount
        let active = viewModel.activeTaskCount
        if active == 0 && done == 0 { return "No tasks yet. Add one to get started." }
        if active == 0 { return "All \(done) tasks complete. Great work!" }
        return "You have completed \(done) of \(viewModel.totalCount) key tasks for today."
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Up Next")
                    .font(.headline(18))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Button("View All Tasks") {}
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.primary)
                    .accessibilityLabel("View all tasks")
            }

            if viewModel.upNextTasks.isEmpty {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.success)
                    Text("You're all caught up!")
                        .font(.body(14))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(viewModel.upNextTasks, id: \.id) { task in
                        DashboardTaskRow(task: task)
                    }
                }
            }
        }
    }

    // MARK: - Activity Insights Card (Stitch dark navy card)

    private var insightsSidebarCard: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Productivity Score
                insightTile(
                    icon: "bolt.fill",
                    iconColor: DesignTokens.Colors.onPrimaryContainer,
                    label: "Productivity Score",
                    value: "\(viewModel.productivityScore)/100"
                )
                // Deep Work Hours
                insightTile(
                    icon: "brain.head.profile",
                    iconColor: DesignTokens.Colors.onPrimaryContainer,
                    label: "Deep Work Hours",
                    value: String(format: "%.1fh", viewModel.deepWorkHours)
                )
            }
        }
    }

    private func insightTile(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body(12))
                    .foregroundStyle(DesignTokens.Colors.onPrimaryContainer)
                    .lineLimit(1)
                Text(value)
                    .font(.headline(16))
                    .foregroundStyle(DesignTokens.Colors.onPrimary)
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Timeline")
                .font(.headline(18))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ForEach(Array(viewModel.todayEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                    TimelineEventRow(event: event, isCurrent: index == 0)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
        }
    }
}

// MARK: - Dashboard Task Row (Stitch bento task card)

private struct DashboardTaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon container
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Colors.priorityColor(task.priority).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: task.category == .deepWork ? "brain.head.profile" : "checkmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.priorityColor(task.priority))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.headline(15))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(task.workspace.rawValue)
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    if let due = task.dueDate {
                        Text("•")
                            .foregroundStyle(DesignTokens.Colors.outlineVariant)
                        Text(due.relativeDisplay)
                            .font(.body(12))
                            .foregroundStyle(due.isOverdue ? DesignTokens.Colors.destructive : DesignTokens.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            PriorityBadge(priority: task.priority)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.priority.label) priority, \(task.workspace.rawValue)")
    }
}

// MARK: - Timeline Event Row

private struct TimelineEventRow: View {
    let event: CalendarEvent
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            // Timeline dot
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? DesignTokens.Colors.primary : DesignTokens.Colors.surfaceHighest)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .fill(isCurrent ? Color.white : DesignTokens.Colors.outline)
                            .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
                    )
                    .shadow(
                        color: isCurrent ? DesignTokens.Colors.primary.opacity(0.3) : .clear,
                        radius: 6, x: 0, y: 0
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                if isCurrent {
                    Text("CURRENT")
                        .font(.label(10, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.primary)
                        .kerning(0.8)
                } else {
                    Text(event.startDate.timeFormatted)
                        .font(.label(10, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .kerning(0.5)
                }

                Text(event.title)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title) at \(event.startDate.timeFormatted)")
    }
}
