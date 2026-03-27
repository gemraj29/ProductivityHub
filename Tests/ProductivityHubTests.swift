// ProductivityHubTests.swift
// Principal Engineer: David Okafor — Quality & Testing Lead
// Comprehensive test suite covering all ViewModels and repositories.
// Every test is isolated, deterministic, and fast.

import XCTest
#if compiler(>=5.9)
import SwiftData
#endif
#if compiler(>=5.9)
@testable import ProductivityHub
#else
@testable import ProductivityHub_Current
#endif

// MARK: - Test Infrastructure

/// In-memory model container for isolated tests
#if compiler(>=5.9)
@MainActor
func makeTestModelContext() throws -> ModelContext {
    let schema = Schema([TaskItem.self, NoteItem.self, CalendarEvent.self, Tag.self])
    let config = ModelConfiguration("TestStore", schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return container.mainContext
}
#else
@MainActor
func makeTestModelContext() throws -> ModelContext {
    ModelContext.clearSharedStorage()
    return ModelContext()
}
#endif

// MARK: - Mock Services

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var authorizationResult: Bool = true
    var scheduledReminders: [TaskID] = []
    var cancelledReminders: [TaskID] = []

    func requestAuthorization() async throws -> Bool {
        authorizationResult
    }

    func scheduleTaskReminder(for task: TaskItem) async throws {
        scheduledReminders.append(task.id)
    }

    func cancelReminder(for taskID: TaskID) async {
        cancelledReminders.append(taskID)
    }
}

final class MockSearchService: SearchServiceProtocol, Sendable {
    func highlightMatches(in text: String, query: String) -> [(range: Range<String.Index>, text: String)] {
        []
    }
}

// MARK: - Test Stubs

extension TaskItem {
    static func stub(
        title: String = "Test Task",
        description: String = "A test task",
        priority: Priority = .medium,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) -> TaskItem {
        let task = TaskItem(
            title: title,
            description: description,
            priority: priority,
            dueDate: dueDate
        )
        if isCompleted { task.markCompleted() }
        return task
    }
}

extension NoteItem {
    static func stub(
        title: String = "Test Note",
        content: String = "Some test content here",
        isPinned: Bool = false
    ) -> NoteItem {
        NoteItem(title: title, content: content, isPinned: isPinned)
    }
}

extension CalendarEvent {
    static func stub(
        title: String = "Test Event",
        startDate: Date = .now,
        endDate: Date = Date.now.addingTimeInterval(3600),
        isAllDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Task Repository Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class TaskRepositoryTests: XCTestCase {
    private var sut: TaskRepository!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = try! makeTestModelContext()
        sut = TaskRepository(modelContext: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    func test_insert_andFetchAll_returnsInsertedTask() throws {
        let task = TaskItem.stub(title: "Buy groceries")
        try sut.insert(task)

        let fetched = try sut.fetchAll()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Buy groceries")
    }

    func test_fetchIncomplete_excludesCompletedTasks() throws {
        let completed = TaskItem.stub(title: "Done Task", isCompleted: true)
        let incomplete = TaskItem.stub(title: "Open Task")
        try sut.insert(completed)
        try sut.insert(incomplete)

        let result = try sut.fetchIncomplete()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Open Task")
    }

    func test_fetchCompleted_returnsOnlyCompletedTasks() throws {
        let completed = TaskItem.stub(title: "Done", isCompleted: true)
        let open = TaskItem.stub(title: "Open")
        try sut.insert(completed)
        try sut.insert(open)

        let result = try sut.fetchCompleted()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Done")
    }

    func test_delete_removesTask() throws {
        let task = TaskItem.stub()
        try sut.insert(task)
        XCTAssertEqual(try sut.fetchAll().count, 1)

        try sut.delete(task)

        XCTAssertEqual(try sut.fetchAll().count, 0)
    }

    func test_fetchOverdue_returnsOnlyOverdueTasks() throws {
        let overdueTask = TaskItem.stub(
            title: "Overdue",
            dueDate: Date.now.addingTimeInterval(-86400)
        )
        let futureTask = TaskItem.stub(
            title: "Future",
            dueDate: Date.now.addingTimeInterval(86400)
        )
        try sut.insert(overdueTask)
        try sut.insert(futureTask)

        let result = try sut.fetchOverdue()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Overdue")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Task List ViewModel Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class TaskListViewModelTests: XCTestCase {
    private var sut: TaskListViewModel!
    private var repo: TaskRepository!
    private var mockNotifications: MockNotificationService!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        repo = TaskRepository(modelContext: context)
        mockNotifications = MockNotificationService()
        sut = TaskListViewModel(
            taskRepository: repo,
            notificationService: mockNotifications
        )
    }

    override func tearDown() {
        sut = nil
        repo = nil
        mockNotifications = nil
        super.tearDown()
    }

    func test_load_setsLoadedState() async throws {
        try repo.insert(.stub(title: "Task A"))
        try repo.insert(.stub(title: "Task B"))

        await sut.load()

        if case .loaded(let tasks) = sut.state {
            XCTAssertEqual(tasks.count, 2)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_toggleCompletion_marksTaskComplete() async throws {
        let task = TaskItem.stub(title: "Toggle Me")
        try repo.insert(task)
        await sut.load()

        await sut.toggleCompletion(for: task)

        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(mockNotifications.cancelledReminders.count, 1)
    }

    func test_toggleCompletion_marksCompletedTaskIncomplete() async throws {
        let task = TaskItem.stub(title: "Re-open", isCompleted: true)
        try repo.insert(task)
        await sut.load()

        await sut.toggleCompletion(for: task)

        XCTAssertFalse(task.isCompleted)
    }

    func test_filteredTasks_respectsShowCompleted() async throws {
        try repo.insert(.stub(title: "Open"))
        try repo.insert(.stub(title: "Done", isCompleted: true))
        await sut.load()

        sut.showCompletedTasks = false
        XCTAssertEqual(sut.filteredTasks.count, 1)
        XCTAssertEqual(sut.filteredTasks.first?.title, "Open")

        sut.showCompletedTasks = true
        XCTAssertEqual(sut.filteredTasks.count, 2)
    }

    func test_filteredTasks_respectsSearchText() async throws {
        try repo.insert(.stub(title: "Buy milk"))
        try repo.insert(.stub(title: "Call dentist"))
        await sut.load()

        sut.searchText = "milk"

        XCTAssertEqual(sut.filteredTasks.count, 1)
        XCTAssertEqual(sut.filteredTasks.first?.title, "Buy milk")
    }

    func test_deleteTask_removesTaskAndCancelsNotification() async throws {
        let task = TaskItem.stub(title: "Delete me")
        try repo.insert(task)
        await sut.load()

        await sut.deleteTask(task)

        XCTAssertEqual(sut.tasks.count, 0)
        XCTAssertEqual(mockNotifications.cancelledReminders.count, 1)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Task Detail ViewModel Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class TaskDetailViewModelTests: XCTestCase {
    private var repo: TaskRepository!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        repo = TaskRepository(modelContext: context)
    }

    override func tearDown() {
        repo = nil
        super.tearDown()
    }

    func test_newTask_isValid_requiresNonEmptyTitle() {
        let sut = TaskDetailViewModel(task: nil, taskRepository: repo)

        sut.title = ""
        XCTAssertFalse(sut.isValid)

        sut.title = "   "
        XCTAssertFalse(sut.isValid)

        sut.title = "Valid Title"
        XCTAssertTrue(sut.isValid)
    }

    func test_newTask_save_insertsTask() async throws {
        let sut = TaskDetailViewModel(task: nil, taskRepository: repo)
        sut.title = "New Task"
        sut.priority = .high

        try await sut.save()

        let tasks = try repo.fetchAll()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "New Task")
        XCTAssertEqual(tasks.first?.priority, .high)
    }

    func test_editTask_save_updatesExistingTask() async throws {
        let existing = TaskItem.stub(title: "Old Title")
        try repo.insert(existing)

        let sut = TaskDetailViewModel(task: existing, taskRepository: repo)
        sut.title = "Updated Title"
        sut.priority = .urgent

        try await sut.save()

        XCTAssertEqual(existing.title, "Updated Title")
        XCTAssertEqual(existing.priority, .urgent)
    }

    func test_save_withEmptyTitle_throws() async {
        let sut = TaskDetailViewModel(task: nil, taskRepository: repo)
        sut.title = ""

        do {
            try await sut.save()
            XCTFail("Expected validation error")
        } catch {
            // Expected
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Note Repository Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class NoteRepositoryTests: XCTestCase {
    private var sut: NoteRepository!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        sut = NoteRepository(modelContext: context)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_insert_andFetchAll_returnsNote() throws {
        try sut.insert(.stub(title: "My Note"))

        let notes = try sut.fetchAll()
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "My Note")
    }

    func test_fetchPinned_returnsPinnedOnly() throws {
        try sut.insert(.stub(title: "Pinned", isPinned: true))
        try sut.insert(.stub(title: "Normal", isPinned: false))

        let pinned = try sut.fetchPinned()
        XCTAssertEqual(pinned.count, 1)
        XCTAssertEqual(pinned.first?.title, "Pinned")
    }

    func test_search_matchesTitleAndContent() throws {
        try sut.insert(.stub(title: "Meeting Notes", content: "Discussed quarterly goals"))
        try sut.insert(.stub(title: "Recipe", content: "Pasta with sauce"))

        let titleMatch = try sut.search(query: "meeting")
        XCTAssertEqual(titleMatch.count, 1)

        let contentMatch = try sut.search(query: "quarterly")
        XCTAssertEqual(contentMatch.count, 1)
    }

    func test_delete_removesNote() throws {
        let note = NoteItem.stub()
        try sut.insert(note)
        XCTAssertEqual(try sut.fetchAll().count, 1)

        try sut.delete(note)
        XCTAssertEqual(try sut.fetchAll().count, 0)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Note List ViewModel Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class NoteListViewModelTests: XCTestCase {
    private var sut: NoteListViewModel!
    private var repo: NoteRepository!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        repo = NoteRepository(modelContext: context)
        sut = NoteListViewModel(
            noteRepository: repo,
            searchService: MockSearchService()
        )
    }

    override func tearDown() {
        sut = nil
        repo = nil
        super.tearDown()
    }

    func test_load_populatesNotes() async throws {
        try repo.insert(.stub(title: "Note A"))
        try repo.insert(.stub(title: "Note B"))

        await sut.load()

        XCTAssertEqual(sut.notes.count, 2)
    }

    func test_pinnedNotes_separatedFromUnpinned() async throws {
        try repo.insert(.stub(title: "Pinned", isPinned: true))
        try repo.insert(.stub(title: "Normal", isPinned: false))
        await sut.load()

        XCTAssertEqual(sut.pinnedNotes.count, 1)
        XCTAssertEqual(sut.unpinnedNotes.count, 1)
    }

    func test_togglePin_switchesPinState() async throws {
        let note = NoteItem.stub(title: "Pin Me", isPinned: false)
        try repo.insert(note)
        await sut.load()

        await sut.togglePin(for: note)

        XCTAssertTrue(note.isPinned)
    }

    func test_deleteNote_removesNote() async throws {
        let note = NoteItem.stub()
        try repo.insert(note)
        await sut.load()
        XCTAssertEqual(sut.notes.count, 1)

        await sut.deleteNote(note)

        XCTAssertEqual(sut.notes.count, 0)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Note Editor ViewModel Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class NoteEditorViewModelTests: XCTestCase {
    private var repo: NoteRepository!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        repo = NoteRepository(modelContext: context)
    }

    func test_isValid_requiresNonEmptyTitle() {
        let sut = NoteEditorViewModel(note: nil, noteRepository: repo)

        sut.title = ""
        XCTAssertFalse(sut.isValid)

        sut.title = "Valid"
        XCTAssertTrue(sut.isValid)
    }

    func test_wordCount_calculatesCorrectly() {
        let sut = NoteEditorViewModel(note: nil, noteRepository: repo)
        sut.content = "Hello world from the test"

        XCTAssertEqual(sut.wordCount, 5)
    }

    func test_save_newNote_insertsIntoRepository() async throws {
        let sut = NoteEditorViewModel(note: nil, noteRepository: repo)
        sut.title = "Fresh Note"
        sut.content = "Content here"

        try await sut.save()

        let notes = try repo.fetchAll()
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "Fresh Note")
    }

    func test_save_existingNote_updatesInPlace() async throws {
        let existing = NoteItem.stub(title: "Original")
        try repo.insert(existing)

        let sut = NoteEditorViewModel(note: existing, noteRepository: repo)
        sut.title = "Edited"
        sut.content = "New content"

        try await sut.save()

        XCTAssertEqual(existing.title, "Edited")
        XCTAssertEqual(existing.content, "New content")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Calendar ViewModel Tests
// ═══════════════════════════════════════════════════════════════

@MainActor
final class CalendarHubViewModelTests: XCTestCase {
    private var sut: CalendarHubViewModel!
    private var repo: CalendarEventRepository!

    override func setUp() {
        super.setUp()
        let context = try! makeTestModelContext()
        repo = CalendarEventRepository(modelContext: context)
        sut = CalendarHubViewModel(
            eventRepository: repo,
            notificationService: MockNotificationService()
        )
    }

    override func tearDown() {
        sut = nil
        repo = nil
        super.tearDown()
    }

    func test_load_fetchesEventsForSelectedDay() async throws {
        let today = Date.now
        try repo.insert(.stub(title: "Today Event", startDate: today))
        try repo.insert(.stub(
            title: "Tomorrow Event",
            startDate: Calendar.current.date(byAdding: .day, value: 1, to: today)!
        ))

        await sut.load()

        XCTAssertEqual(sut.eventsForSelectedDay.count, 1)
        XCTAssertEqual(sut.eventsForSelectedDay.first?.title, "Today Event")
    }

    func test_createEvent_addsEventAndReloads() async throws {
        try await sut.createEvent(
            title: "Team Standup",
            description: "Daily sync",
            startDate: .now,
            endDate: Date.now.addingTimeInterval(1800),
            isAllDay: false,
            colorHex: "#FF453A"
        )

        XCTAssertEqual(sut.eventsForSelectedDay.count, 1)
    }

    func test_createEvent_emptyTitle_throws() async {
        do {
            try await sut.createEvent(
                title: "",
                description: "",
                startDate: .now,
                endDate: Date.now.addingTimeInterval(3600),
                isAllDay: false,
                colorHex: "#5E5CE6"
            )
            XCTFail("Expected validation error")
        } catch {
            // Expected
        }
    }

    func test_createEvent_endBeforeStart_throws() async {
        do {
            try await sut.createEvent(
                title: "Bad Event",
                description: "",
                startDate: Date.now.addingTimeInterval(3600),
                endDate: .now,
                isAllDay: false,
                colorHex: "#5E5CE6"
            )
            XCTFail("Expected validation error")
        } catch {
            // Expected
        }
    }

    func test_deleteEvent_removesEvent() async throws {
        let event = CalendarEvent.stub(title: "Delete Me")
        try repo.insert(event)
        await sut.load()
        XCTAssertEqual(sut.eventsForSelectedDay.count, 1)

        await sut.deleteEvent(event)

        XCTAssertEqual(sut.eventsForSelectedDay.count, 0)
    }

    func test_selectDate_updatesEventsForNewDay() async throws {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        try repo.insert(.stub(title: "Tomorrow's Event", startDate: tomorrow))

        await sut.selectDate(tomorrow)

        XCTAssertEqual(sut.eventsForSelectedDay.count, 1)
        XCTAssertEqual(sut.eventsForSelectedDay.first?.title, "Tomorrow's Event")
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Model Unit Tests
// ═══════════════════════════════════════════════════════════════

final class ModelTests: XCTestCase {
    func test_taskItem_markCompleted_setsDateAndFlag() {
        let task = TaskItem.stub()
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedDate)

        task.markCompleted()

        XCTAssertTrue(task.isCompleted)
        XCTAssertNotNil(task.completedDate)
    }

    func test_taskItem_markIncomplete_clearsCompletedDate() {
        let task = TaskItem.stub(isCompleted: true)
        task.markIncomplete()

        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedDate)
    }

    func test_noteItem_wordCount_calculatesCorrectly() {
        let note = NoteItem.stub(content: "One two three four five")
        XCTAssertEqual(note.wordCount, 5)
    }

    func test_noteItem_previewText_returnsTwoLines() {
        let note = NoteItem.stub(content: "Line one\nLine two\nLine three")
        let preview = note.previewText
        XCTAssertTrue(preview.contains("Line one"))
        XCTAssertTrue(preview.contains("Line two"))
        XCTAssertFalse(preview.contains("Line three"))
    }

    func test_calendarEvent_durationMinutes_calculatesCorrectly() {
        let start = Date.now
        let end = start.addingTimeInterval(5400) // 90 minutes
        let event = CalendarEvent.stub(startDate: start, endDate: end)

        XCTAssertEqual(event.durationMinutes, 90)
    }

    func test_priority_ordering() {
        XCTAssertTrue(Priority.low < Priority.medium)
        XCTAssertTrue(Priority.medium < Priority.high)
        XCTAssertTrue(Priority.high < Priority.urgent)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Search Service Tests
// ═══════════════════════════════════════════════════════════════

final class SearchServiceTests: XCTestCase {
    private let sut = SearchService()

    func test_highlightMatches_findsAllOccurrences() {
        let matches = sut.highlightMatches(in: "Hello world, hello there", query: "hello")

        XCTAssertEqual(matches.count, 2)
    }

    func test_highlightMatches_caseInsensitive() {
        let matches = sut.highlightMatches(in: "Swift is SWIFT", query: "swift")

        XCTAssertEqual(matches.count, 2)
    }

    func test_highlightMatches_emptyQuery_returnsEmpty() {
        let matches = sut.highlightMatches(in: "Some text", query: "")

        XCTAssertTrue(matches.isEmpty)
    }
}
