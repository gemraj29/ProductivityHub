// DependencyContainer.swift
// Principal Engineer: Rajesh Vallepalli — Chief Architect
// Centralized DI container — all dependencies flow from here.

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

    private let taskRepository:          TaskRepositoryProtocol
    private let noteRepository:          NoteRepositoryProtocol
    private let calendarEventRepository: CalendarEventRepositoryProtocol

    // MARK: - Services

    private let notificationService: NotificationServiceProtocol
    private let searchService:       SearchServiceProtocol

    // MARK: - Init

    private init() {
        let schema = Schema([TaskItem.self, NoteItem.self, CalendarEvent.self, Tag.self])

        // Resolve the on-disk store URL so we can nuke it on migration failure.
        let storeURL = URL.applicationSupportDirectory
            .appending(component: "ProductivityHub.store", directoryHint: .notDirectory)

        // Ensure the Application Support directory exists — iOS does not create it automatically.
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let config = ModelConfiguration(
            "ProductivityHub",
            schema: schema,
            url: storeURL
        )

        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [config])
        }

        do {
            self.modelContainer = try makeContainer()
        } catch {
            // Schema migration failed (e.g. new non-optional columns added).
            // Destroy the legacy store and start fresh — acceptable for a dev build.
            let sidecarExtensions = ["", "-shm", "-wal"]
            for ext in sidecarExtensions {
                let candidate = storeURL.deletingPathExtension()
                    .appendingPathExtension("store\(ext)")
                try? FileManager.default.removeItem(at: candidate)
            }
            // Also try the exact storeURL just in case.
            try? FileManager.default.removeItem(at: storeURL)

            do {
                self.modelContainer = try makeContainer()
            } catch {
                fatalError("ModelContainer failed even after store reset: \(error.localizedDescription)")
            }
        }

        let context = modelContainer.mainContext
        self.taskRepository          = TaskRepository(modelContext: context)
        self.noteRepository          = NoteRepository(modelContext: context)
        self.calendarEventRepository = CalendarEventRepository(modelContext: context)
        self.notificationService     = NotificationService()
        self.searchService           = SearchService()
    }

    // MARK: - Factory Methods

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            taskRepository:  taskRepository,
            eventRepository: calendarEventRepository
        )
    }

    func makeTaskListViewModel() -> TaskListViewModel {
        TaskListViewModel(
            taskRepository:      taskRepository,
            notificationService: notificationService
        )
    }

    func makeTaskDetailViewModel(task: TaskItem?) -> TaskDetailViewModel {
        TaskDetailViewModel(task: task, taskRepository: taskRepository)
    }

    func makeNoteListViewModel() -> NoteListViewModel {
        NoteListViewModel(noteRepository: noteRepository, searchService: searchService)
    }

    func makeNoteEditorViewModel(note: NoteItem?) -> NoteEditorViewModel {
        NoteEditorViewModel(note: note, noteRepository: noteRepository)
    }

    func makeCalendarViewModel() -> CalendarHubViewModel {
        CalendarHubViewModel(
            eventRepository:     calendarEventRepository,
            notificationService: notificationService
        )
    }

    func makeFocusModeViewModel() -> FocusModeViewModel {
        FocusModeViewModel()
    }

    func makeStatsViewModel() -> StatsViewModel {
        StatsViewModel(taskRepository: taskRepository)
    }
}
