// DependencyContainer.swift
// Principal Engineer: Rajesh Vallepalli — Chief Architect
// Centralized DI container — all dependencies flow from here.
// Every concrete type is hidden behind a protocol.

import SwiftUI
#if compiler(>=5.9)
import SwiftData
#endif

@MainActor
final class DependencyContainer: Sendable {
    static let shared = DependencyContainer()

    // MARK: - SwiftData

    let modelContainer: ModelContainer

    // MARK: - Repositories

    private let taskRepository: TaskRepositoryProtocol
    private let noteRepository: NoteRepositoryProtocol
    private let calendarEventRepository: CalendarEventRepositoryProtocol

    // MARK: - Services

    private let notificationService: NotificationServiceProtocol
    private let searchService: SearchServiceProtocol

    // MARK: - Init

    private init() {
        let schema = Schema([
            TaskItem.self,
            NoteItem.self,
            CalendarEvent.self,
            Tag.self
        ])
        let config = ModelConfiguration(
            "ProductivityHub",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }

        let context = modelContainer.mainContext

        self.taskRepository = TaskRepository(modelContext: context)
        self.noteRepository = NoteRepository(modelContext: context)
        self.calendarEventRepository = CalendarEventRepository(modelContext: context)
        self.notificationService = NotificationService()
        self.searchService = SearchService()
    }

    // MARK: - Factory Methods

    func makeTaskListViewModel() -> TaskListViewModel {
        TaskListViewModel(
            taskRepository: taskRepository,
            notificationService: notificationService
        )
    }

    func makeTaskDetailViewModel(task: TaskItem?) -> TaskDetailViewModel {
        TaskDetailViewModel(
            task: task,
            taskRepository: taskRepository
        )
    }

    func makeNoteListViewModel() -> NoteListViewModel {
        NoteListViewModel(
            noteRepository: noteRepository,
            searchService: searchService
        )
    }

    func makeNoteEditorViewModel(note: NoteItem?) -> NoteEditorViewModel {
        NoteEditorViewModel(
            note: note,
            noteRepository: noteRepository
        )
    }

    func makeCalendarViewModel() -> CalendarHubViewModel {
        CalendarHubViewModel(
            eventRepository: calendarEventRepository,
            notificationService: notificationService
        )
    }
}
