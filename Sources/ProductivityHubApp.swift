// ProductivityHubApp.swift
// Principal Engineer: Rajesh Vallepalli — Chief Architect
// Architecture: MVVM + Coordinator with Clean Architecture layers
// Target: iOS 17+ | SwiftUI | SwiftData
//
// Module Structure:
//   App/          → Entry point, DI container, root coordinator
//   Core/         → Shared types, extensions, design tokens
//   Domain/       → Models, repository protocols, use cases
//   Data/         → SwiftData persistence, concrete repositories
//   Networking/   → API client, endpoints, DTOs
//   Features/     → Tasks, Notes, Calendar — each with View + ViewModel
//   DesignSystem/ → Reusable UI components, theme, animations
//   Tests/        → Unit + integration tests

import SwiftUI
#if compiler(>=5.9)
import SwiftData
#endif

// MARK: - App Entry Point

@main
struct ProductivityHubApp: App {
    private let container: DependencyContainer

    init() {
        self.container = DependencyContainer.shared
    }

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
    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(
                viewModel: container.makeTaskListViewModel()
            )
            .tabItem {
                Label(AppTab.tasks.title, systemImage: AppTab.tasks.icon)
            }
            .tag(AppTab.tasks)

            NoteListView(
                viewModel: container.makeNoteListViewModel()
            )
            .tabItem {
                Label(AppTab.notes.title, systemImage: AppTab.notes.icon)
            }
            .tag(AppTab.notes)

            CalendarHubView(
                viewModel: container.makeCalendarViewModel()
            )
            .tabItem {
                Label(AppTab.calendar.title, systemImage: AppTab.calendar.icon)
            }
            .tag(AppTab.calendar)
        }
        .tint(DesignTokens.Colors.accent)
    }
}

// MARK: - App Tab Definition

enum AppTab: String, CaseIterable, Sendable {
    case tasks
    case notes
    case calendar

    var title: String {
        switch self {
        case .tasks:    return "Tasks"
        case .notes:    return "Notes"
        case .calendar: return "Calendar"
        }
    }

    var icon: String {
        switch self {
        case .tasks:    return "checklist"
        case .notes:    return "note.text"
        case .calendar: return "calendar"
        }
    }
}
