// RepositoryProtocols.swift
// Principal Engineer: Rajesh Vallepalli — Data & Persistence Lead
// Repository contracts — the domain layer depends only on these.
// Concrete implementations live in the Data layer.

import Foundation

// MARK: - Task Repository

// Protocols are not @MainActor: repositories are called from @MainActor ViewModels
// (which provides actor isolation at the call site) but tests need to call them from
// async Tasks without triggering Swift 5.10 runtime actor-isolation checks.
protocol TaskRepositoryProtocol: AnyObject, Sendable {
    func fetchAll() throws -> [TaskItem]
    func fetchIncomplete() throws -> [TaskItem]
    func fetchCompleted() throws -> [TaskItem]
    func fetchOverdue() throws -> [TaskItem]
    func fetchByTag(_ tag: Tag) throws -> [TaskItem]
    func insert(_ task: TaskItem) throws
    func delete(_ task: TaskItem) throws
    func save() throws
}

// MARK: - Note Repository

protocol NoteRepositoryProtocol: AnyObject, Sendable {
    func fetchAll() throws -> [NoteItem]
    func fetchPinned() throws -> [NoteItem]
    func search(query: String) throws -> [NoteItem]
    func fetchByTag(_ tag: Tag) throws -> [NoteItem]
    func insert(_ note: NoteItem) throws
    func delete(_ note: NoteItem) throws
    func save() throws
}

// MARK: - Calendar Event Repository

protocol CalendarEventRepositoryProtocol: AnyObject, Sendable {
    func fetchAll() throws -> [CalendarEvent]
    func fetchEvents(from startDate: Date, to endDate: Date) throws -> [CalendarEvent]
    func fetchEventsForDay(_ date: Date) throws -> [CalendarEvent]
    func insert(_ event: CalendarEvent) throws
    func delete(_ event: CalendarEvent) throws
    func save() throws
}

// MARK: - Services

protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleTaskReminder(for task: TaskItem) async throws
    func cancelReminder(for taskID: TaskID) async
}

protocol SearchServiceProtocol: Sendable {
    func highlightMatches(in text: String, query: String) -> [(range: Range<String.Index>, text: String)]
}
