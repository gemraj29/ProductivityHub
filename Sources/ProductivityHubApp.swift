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
    @State private var showingAdd          = false

    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var taskViewModel:      TaskListViewModel
    @StateObject private var statsViewModel:     StatsViewModel
    @StateObject private var calendarViewModel:  CalendarHubViewModel

    init(container: DependencyContainer) {
        self.container = container
        _dashboardViewModel = StateObject(wrappedValue: container.makeDashboardViewModel())
        _taskViewModel      = StateObject(wrappedValue: container.makeTaskListViewModel())
        _statsViewModel     = StateObject(wrappedValue: container.makeStatsViewModel())
        _calendarViewModel  = StateObject(wrappedValue: container.makeCalendarViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel)
                .tabItem { Label(AppTab.home.title,     systemImage: AppTab.home.icon)     }.tag(AppTab.home)
            TaskListView(viewModel: taskViewModel)
                .tabItem { Label(AppTab.tasks.title,    systemImage: AppTab.tasks.icon)    }.tag(AppTab.tasks)
            StatsView(viewModel: statsViewModel)
                .tabItem { Label(AppTab.stats.title,    systemImage: AppTab.stats.icon)    }.tag(AppTab.stats)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }.tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DeepSeaTabBar(selectedTab: $selectedTab, onAdd: { showingAdd = true })
        }
        .tint(DesignTokens.Colors.accent)
        .sheet(isPresented: $showingAdd) {
            TaskDetailSheet(viewModel: container.makeTaskDetailViewModel(task: nil))
        }
    }
}

// MARK: - Deep Sea Tab Bar

private struct DeepSeaTabBar: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    private let leftTabs:  [AppTab] = [.home,  .tasks   ]
    private let rightTabs: [AppTab] = [.stats, .settings]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leftTabs,  id: \.self) { DeepSeaTabItem(tab: $0, selectedTab: $selectedTab) }

            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.accent)
                        .frame(width: 52, height: 52)
                        .shadow(color: DesignTokens.Colors.accent.opacity(0.45), radius: 10, x: 0, y: 5)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -12)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add new task")

            ForEach(rightTabs, id: \.self) { DeepSeaTabItem(tab: $0, selectedTab: $selectedTab) }
        }
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .frame(height: 52)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider().opacity(0.5) }
        }
    }
}

private struct DeepSeaTabItem: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab
    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DesignTokens.Colors.accent : Color(.tertiaryLabel))
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DesignTokens.Colors.accent : Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - App Tab Definition

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home, tasks, stats, settings

    var title: String {
        switch self {
        case .home: return "Home"; case .tasks: return "Tasks"
        case .stats: return "Stats"; case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"; case .tasks: return "list.bullet"
        case .stats: return "chart.bar"; case .settings: return "gearshape"
        }
    }

    var filledIcon: String {
        switch self {
        case .home: return "house.fill"; case .tasks: return "list.bullet"
        case .stats: return "chart.bar.fill"; case .settings: return "gearshape.fill"
        }
    }
}
