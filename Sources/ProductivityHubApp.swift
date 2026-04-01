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
//
// ViewModels are stored as @StateObject so SwiftUI owns them for the lifetime
// of this view. Previously they were created inside `body` (a computed property),
// which recreated a fresh ViewModel — and replaced the child's @ObservedObject —
// on every parent re-render (e.g. tab switch). That caused all in-memory state
// to reset and made task/note creation appear to fail.

struct RootCoordinatorView: View {
    let container: DependencyContainer
    @State private var selectedTab: AppTab = .tasks
    @StateObject private var taskViewModel: TaskListViewModel
    @StateObject private var noteViewModel: NoteListViewModel
    @StateObject private var calendarViewModel: CalendarHubViewModel

    init(container: DependencyContainer) {
        self.container = container
        _taskViewModel   = StateObject(wrappedValue: container.makeTaskListViewModel())
        _noteViewModel   = StateObject(wrappedValue: container.makeNoteListViewModel())
        _calendarViewModel = StateObject(wrappedValue: container.makeCalendarViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(viewModel: taskViewModel)
                .tabItem {
                    Label(AppTab.tasks.title, systemImage: AppTab.tasks.icon)
                }
                .tag(AppTab.tasks)

            NoteListView(viewModel: noteViewModel)
                .tabItem {
                    Label(AppTab.notes.title, systemImage: AppTab.notes.icon)
                }
                .tag(AppTab.notes)

            CalendarHubView(viewModel: calendarViewModel)
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
