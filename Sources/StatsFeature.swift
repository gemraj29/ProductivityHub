// StatsFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Performance Analytics: task stats, completion trends, efficiency pulse, daily insight.

import SwiftUI
import Charts

// MARK: - Day Completion Model

struct DayCompletion: Identifiable {
    let id   = UUID()
    let label: String
    let count: Int
    let isToday: Bool
}

// MARK: - Stats ViewModel

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var totalCompleted:  Int              = 0
    @Published private(set) var avgDailyTasks:   Double           = 0
    @Published private(set) var longestStreak:   Int              = 0
    @Published private(set) var weeklyData:      [DayCompletion]  = []
    @Published private(set) var selectedPeriod:  StatsPeriod      = .week
    @Published private(set) var state: LoadingState<Bool>         = .idle

    enum StatsPeriod: String, CaseIterable {
        case week  = "Week"
        case month = "Month"
    }

    private let taskRepository: TaskRepositoryProtocol

    init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }

    deinit {
        #if DEBUG
        print("StatsViewModel deinitialized")
        #endif
    }

    func selectPeriod(_ period: StatsPeriod) {
        selectedPeriod = period
    }

    func load() async {
        state = .loading
        do {
            let all       = try taskRepository.fetchAll()
            let completed = all.filter { $0.isCompleted }

            totalCompleted = completed.count
            longestStreak  = computeStreak(from: completed)
            weeklyData     = computeWeeklyData(from: completed)

            let activeDays = max(1, weeklyData.filter { $0.count > 0 }.count)
            let weekTotal  = weeklyData.reduce(0) { $0 + $1.count }
            avgDailyTasks  = Double(weekTotal) / Double(activeDays)

            state = .loaded(true)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    // MARK: - Private

    private func computeStreak(from tasks: [TaskItem]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Set(
            tasks.compactMap { $0.completedDate }
                 .map { calendar.startOfDay(for: $0) }
        ).sorted(by: >)

        var streak   = 0
        var expected = calendar.startOfDay(for: .now)

        for day in uniqueDays {
            if day == expected {
                streak  += 1
                expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
            } else if day < expected {
                break
            }
        }
        return streak
    }

    private func computeWeeklyData(from completed: [TaskItem]) -> [DayCompletion] {
        let calendar       = Calendar.current
        let today          = calendar.startOfDay(for: .now)
        let weekdayLabels  = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

        return (0..<7).reversed().compactMap { daysAgo -> DayCompletion? in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let count   = completed.filter { task in
                task.completedDate.map { calendar.isDate($0, inSameDayAs: day) } == true
            }.count
            let weekday = calendar.component(.weekday, from: day)
            return DayCompletion(
                label:   weekdayLabels[weekday - 1],
                count:   count,
                isToday: daysAgo == 0
            )
        }
    }
}

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {

                        // Section label
                        Text("Performance Analytics")
                            .sectionLabel()
                            .padding(.top, DesignTokens.Spacing.sm)

                        // Page title
                        Text("Productivity Stats")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .padding(.top, -DesignTokens.Spacing.md)

                        // Top stats grid
                        statsGrid

                        // Completion trends chart
                        trendsCard

                        // Efficiency Pulse
                        efficiencyCard

                        // Daily Insight
                        insightCard
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Productivity", showSearch: false)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            DSStatCard(
                icon: "checkmark.circle.fill",
                iconColor: DesignTokens.Colors.success,
                value: "\(viewModel.totalCompleted)",
                label: "Total Tasks Completed",
                badge: viewModel.totalCompleted > 0 ? "+12%" : nil
            )

            HStack(spacing: DesignTokens.Spacing.md) {
                DSStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: DesignTokens.Colors.accent,
                    value: String(format: "%.1f", viewModel.avgDailyTasks),
                    label: "Avg. Daily\nProductivity"
                )

                DSStatCard(
                    icon: "flame.fill",
                    iconColor: DesignTokens.Colors.warning,
                    value: "\(viewModel.longestStreak)",
                    label: "Longest\nStreak (days)"
                )
            }
        }
    }

    // MARK: - Trends Card

    private var trendsCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Task Completion Trends")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                        Text("Weekly performance overview")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    Spacer()
                    periodPicker
                }

                completionChart
                    .frame(height: 140)
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsViewModel.StatsPeriod.allCases, id: \.self) { period in
                Button {
                    viewModel.selectPeriod(period)
                } label: {
                    Text(period.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            viewModel.selectedPeriod == period
                                ? DesignTokens.Colors.textInverse
                                : DesignTokens.Colors.textSecondary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(
                            viewModel.selectedPeriod == period
                                ? DesignTokens.Colors.accent
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DesignTokens.Colors.backgroundApp, in: Capsule())
    }

    private var completionChart: some View {
        Chart(viewModel.weeklyData) { day in
            BarMark(
                x: .value("Day", day.label),
                y: .value("Tasks", day.count)
            )
            .foregroundStyle(
                day.isToday
                    ? DesignTokens.Colors.accent
                    : DesignTokens.Colors.accent.opacity(0.35)
            )
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DesignTokens.Colors.textTertiary.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }

    // MARK: - Efficiency Card

    private var efficiencyCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Efficiency Pulse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                EfficiencyRow(
                    icon: "bolt.fill",
                    iconColor: DesignTokens.Colors.accent,
                    label: "Deep Focus Ratio",
                    value: 78
                )

                Divider()

                EfficiencyRow(
                    icon: "target",
                    iconColor: DesignTokens.Colors.destructive,
                    label: "Time Estimation Accuracy",
                    value: 92
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
            .fill(DesignTokens.Colors.backgroundNavy)
            .overlay(
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Daily Insight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    Text("\"Your peak productivity window occurs between 9:00 AM and 11:30 AM. Scheduling your high-impact tasks during this window has increased completion rates by 24% this week.\"")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Colors.textInverse)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        // Optimize schedule action
                    } label: {
                        Text("Optimize Schedule")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(DesignTokens.Colors.backgroundCard, in: Capsule())
                    }
                    .accessibilityLabel("Optimize your schedule")
                }
                .padding(DesignTokens.Spacing.lg)
            )
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Efficiency Row

private struct EfficiencyRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            Text("\(value)%")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) percent")
    }
}
