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
    @State private var showingAdd = false
    @StateObject private var taskViewModel: TaskListViewModel
    @StateObject private var noteViewModel: NoteListViewModel
    @StateObject private var calendarViewModel: CalendarHubViewModel

    init(container: DependencyContainer) {
        self.container = container
        _taskViewModel     = StateObject(wrappedValue: container.makeTaskListViewModel())
        _noteViewModel     = StateObject(wrappedValue: container.makeNoteListViewModel())
        _calendarViewModel = StateObject(wrappedValue: container.makeCalendarViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TaskListView(viewModel: taskViewModel)
                .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.icon) }
                .tag(AppTab.tasks)

            NoteListView(viewModel: noteViewModel)
                .tabItem { Label(AppTab.notes.title, systemImage: AppTab.notes.icon) }
                .tag(AppTab.notes)

            CalendarHubView(viewModel: calendarViewModel)
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.icon) }
                .tag(AppTab.calendar)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selectedTab: $selectedTab, onAdd: { showingAdd = true })
        }
        .tint(DesignTokens.Colors.accent)
        .sheet(isPresented: $showingAdd) {
            addSheetContent
        }
    }

    @ViewBuilder
    private var addSheetContent: some View {
        switch selectedTab {
        case .tasks:
            TaskDetailSheet(viewModel: container.makeTaskDetailViewModel(task: nil))
        case .notes:
            NoteEditorSheet(viewModel: container.makeNoteEditorViewModel(note: nil))
        case .calendar:
            EventCreationSheet(
                initialDate: calendarViewModel.selectedDate,
                onSave: { title, desc, start, end, allDay, color in
                    try await calendarViewModel.createEvent(
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
}

// MARK: - Bottom Tab Bar

private struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            BottomTabItem(tab: .tasks, selectedTab: $selectedTab)
            BottomTabItem(tab: .notes, selectedTab: $selectedTab)

            // Center elevated + button
            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.accent)
                        .frame(width: 50, height: 50)
                        .shadow(
                            color: DesignTokens.Colors.accent.opacity(0.4),
                            radius: 8, x: 0, y: 4
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -10)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add new item")

            BottomTabItem(tab: .calendar, selectedTab: $selectedTab)
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
        .frame(height: 49)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

private struct BottomTabItem: View {
    let tab: AppTab
    @Binding var selectedTab: AppTab

    private var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.accent : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
