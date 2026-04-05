// ProductivityHubApp.swift
// Principal Engineer: Rajesh Vallepalli — Chief Architect
// Architecture: MVVM + Coordinator with Clean Architecture layers
// Target: iOS 17+ | SwiftUI | SwiftData

import SwiftUI
#if compiler(>=5.9)
import SwiftData
#endif

// MARK: - App Entry Point

@main
struct ProductivityHubApp: App {
    private let container: DependencyContainer

    init() { self.container = DependencyContainer.shared }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView(container: container)
                .modelContainer(container.modelContainer)
        }
    }
}

// MARK: - Root Coordinator

struct RootCoordinatorView: View {
    let container: DependencyContainer
    @State private var selectedTab: AppTab = .home
    @State private var showingAdd = false

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var taskViewModel:      TaskListViewModel
    @StateObject private var focusViewModel:     FocusModeViewModel
    @StateObject private var calendarViewModel:  CalendarHubViewModel
    @StateObject private var statsViewModel:     StatsViewModel

    init(container: DependencyContainer) {
        self.container = container
        _dashboardViewModel = StateObject(wrappedValue: container.makeDashboardViewModel())
        _taskViewModel      = StateObject(wrappedValue: container.makeTaskListViewModel())
        _focusViewModel     = StateObject(wrappedValue: container.makeFocusModeViewModel())
        _calendarViewModel  = StateObject(wrappedValue: container.makeCalendarViewModel())
        _statsViewModel     = StateObject(wrappedValue: container.makeStatsViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(viewModel: dashboardViewModel)
                    .tag(AppTab.home)
                TaskListView(viewModel: taskViewModel)
                    .tag(AppTab.tasks)
                FocusModeView(viewModel: focusViewModel)
                    .tag(AppTab.focus)
                CalendarHubView(viewModel: calendarViewModel)
                    .tag(AppTab.calendar)
                StatsView(viewModel: statsViewModel)
                    .tag(AppTab.stats)
            }
            .toolbar(.hidden, for: .tabBar)

            DeepSeaTabBar(selectedTab: $selectedTab, onAdd: { showingAdd = true })
        }
        .tint(DesignTokens.Colors.primary)
        .sheet(isPresented: $showingAdd) {
            TaskDetailSheet(viewModel: container.makeTaskDetailViewModel(task: nil))
        }
    }
}

// MARK: - Deep Sea Tab Bar (Stitch-style)

private struct DeepSeaTabBar: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                DeepSeaTabItem(tab: tab, selectedTab: $selectedTab, onAdd: onAdd)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color(hex: "#00334d").opacity(0.08), radius: 20, x: 0, y: -8)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl, style: .continuous)
                        .fill(Color(hex: "#ffffff").opacity(0.8))
                        .frame(height: DesignTokens.Radius.xxxl * 2)
                        .offset(y: -DesignTokens.Radius.xxxl)
                }
        }
    }
}

private struct DeepSeaTabItem: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Group {
                if isSelected {
                    Image(systemName: tab.filledIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.Colors.onPrimary)
                        .frame(width: 48, height: 48)
                        .background(LinearGradient.deepSeaPrimary, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                        .shadow(color: DesignTokens.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 4)
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.Colors.onSurfaceVariant)
                        .frame(width: 48, height: 48)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - App Tab Definition (5-tab matching Stitch)

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home
    case tasks
    case focus
    case calendar
    case stats

    var title: String {
        switch self {
        case .home:     return "Home"
        case .tasks:    return "Tasks"
        case .focus:    return "Focus"
        case .calendar: return "Calendar"
        case .stats:    return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .tasks:    return "list.bullet.rectangle"
        case .focus:    return "timer"
        case .calendar: return "calendar"
        case .stats:    return "chart.bar"
        }
    }

    var filledIcon: String {
        switch self {
        case .home:     return "house.fill"
        case .tasks:    return "list.bullet.rectangle.fill"
        case .focus:    return "timer"
        case .calendar: return "calendar"
        case .stats:    return "chart.bar.fill"
        }
    }
}
