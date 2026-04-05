// StatsFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Performance Analytics: stat cards, bar chart, efficiency pulse, daily insight.
// Design: matches Stitch productivity_stats/code.html exactly.

import SwiftUI
import Charts

// MARK: - Day Completion Model

struct DayCompletion: Identifiable {
    let id    = UUID()
    let label: String
    let count: Int
    let isToday: Bool
}

// MARK: - Stats ViewModel

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var totalCompleted: Int             = 0
    @Published private(set) var avgDailyTasks:  Double          = 0
    @Published private(set) var longestStreak:  Int             = 0
    @Published private(set) var weeklyData:     [DayCompletion] = []
    @Published var selectedPeriod:  StatsPeriod = .week
    @Published private(set) var state: LoadingState<Bool>       = .idle

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

    // MARK: Private Helpers

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
        let calendar      = Calendar.current
        let today         = calendar.startOfDay(for: .now)
        let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

        return (0..<7).reversed().compactMap { daysAgo -> DayCompletion? in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let count   = completed.filter { task in
                task.completedDate.map { calendar.isDate($0, inSameDayAs: day) } == true
            }.count
            let weekday = calendar.component(.weekday, from: day)
            return DayCompletion(label: weekdayLabels[weekday - 1], count: count, isToday: daysAgo == 0)
        }
    }
}

// MARK: - Stats View (Stitch layout)

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        pageHeader.padding(.top, DesignTokens.Spacing.sm)
                        statsGrid
                        trendsCard
                        bottomRow
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity", showSearch: false)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("PERFORMANCE ANALYTICS")
                .sectionLabel()

            Text("Productivity Stats")
                .font(.headline(30))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            // Accent underline (Stitch: w-20 h-1 gradient)
            LinearGradient.deepSeaPrimary
                .frame(width: 64, height: 3)
                .clipShape(Capsule())
        }
    }

    // MARK: Stats Grid (Stitch 3-card bento)

    private var statsGrid: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Total Tasks Completed (full-width)
            DSStatCard(
                icon: "checkmark.circle.fill",
                iconColor: DesignTokens.Colors.primary,
                value: "\(viewModel.totalCompleted)",
                label: "Total Tasks Completed",
                badge: viewModel.totalCompleted > 0 ? "+12%" : nil
            )

            HStack(spacing: DesignTokens.Spacing.md) {
                DSStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: DesignTokens.Colors.primary,
                    value: String(format: "%.1f", viewModel.avgDailyTasks),
                    label: "Avg. Daily\nProductivity"
                )

                DSStatCard(
                    icon: "flame.fill",
                    iconColor: DesignTokens.Colors.tertiaryContainer,
                    value: "\(viewModel.longestStreak)",
                    label: "Longest\nStreak (days)"
                )
            }
        }
    }

    // MARK: Trends Card (Stitch bar chart)

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Task Completion Trends")
                        .font(.headline(17))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("Weekly performance overview")
                        .font(.body(13))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                Spacer()
                periodPicker
            }

            completionChart
                .frame(height: 160)
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsViewModel.StatsPeriod.allCases, id: \.self) { period in
                Button { viewModel.selectPeriod(period) } label: {
                    Text(period.rawValue)
                        .font(.label(12, weight: .semibold))
                        .foregroundStyle(
                            viewModel.selectedPeriod == period
                                ? DesignTokens.Colors.primary
                                : DesignTokens.Colors.textSecondary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(
                            viewModel.selectedPeriod == period
                                ? DesignTokens.Colors.backgroundCard
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                        )
                        .shadow(
                            color: viewModel.selectedPeriod == period ? Color.black.opacity(0.06) : .clear,
                            radius: 4, x: 0, y: 2
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DesignTokens.Colors.surfaceHighest, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var completionChart: some View {
        Chart(viewModel.weeklyData) { day in
            BarMark(
                x: .value("Day", day.label),
                y: .value("Tasks", day.count)
            )
            .foregroundStyle(
                day.isToday
                    ? AnyShapeStyle(LinearGradient.deepSeaPrimary)
                    : AnyShapeStyle(DesignTokens.Colors.secondaryContainer)
            )
            .cornerRadius(6)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DesignTokens.Colors.outlineVariant.opacity(0.3))
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }

    // MARK: Bottom Row: Efficiency Pulse + Daily Insight

    private var bottomRow: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            efficiencyCard
            insightCard
        }
    }

    private var efficiencyCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Efficiency Pulse")
                .font(.headline(17))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            EfficiencyBar(
                icon: "bolt.fill",
                iconBg: DesignTokens.Colors.primaryFixed,
                iconColor: DesignTokens.Colors.onPrimaryFixedVariant,
                label: "Deep Focus Ratio",
                value: 78,
                trackColor: DesignTokens.Colors.primary
            )

            Divider()
                .opacity(0.5)

            EfficiencyBar(
                icon: "timer",
                iconBg: DesignTokens.Colors.tertiaryFixed,
                iconColor: DesignTokens.Colors.tertiaryContainer,
                label: "Time Estimation Accuracy",
                value: 92,
                trackColor: DesignTokens.Colors.tertiary
            )
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
        .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private var insightCard: some View {
        ZStack(alignment: .bottomTrailing) {
            // Decorative glow
            Circle()
                .fill(DesignTokens.Colors.primaryContainer.opacity(0.25))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
                .offset(x: 20, y: 20)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Daily Insight")
                    .font(.headline(17))
                    .foregroundStyle(Color.white)

                Text("\"Your peak productivity window occurs between **9:00 AM and 11:30 AM**. Scheduling your high-impact tasks during this window has increased completion rates by 24% this week.\"")
                    .font(.body(14))
                    .foregroundStyle(DesignTokens.Colors.onPrimaryContainer)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    // Optimize schedule action
                } label: {
                    Text("Optimize Schedule")
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                .accessibilityLabel("Optimize your schedule")
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(
            LinearGradient.deepSeaPrimary,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl)
        )
        .clipped()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Efficiency Bar (Stitch progress row)

private struct EfficiencyBar: View {
    let icon:       String
    let iconBg:     Color
    let iconColor:  Color
    let label:      String
    let value:      Int
    let trackColor: Color

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle().fill(iconBg).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text(label)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Spacer()
                    Text("\(value)%")
                        .font(.body(14, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }

                // Progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DesignTokens.Colors.surfaceHighest)
                            .frame(height: 6)
                        LinearGradient(
                            colors: [trackColor, trackColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * CGFloat(value) / 100, height: 6)
                        .clipShape(Capsule())
                    }
                }
                .frame(height: 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) percent")
    }
}
