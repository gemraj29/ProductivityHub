// Repositories.swift
// Principal Engineer: Rajesh Vallepalli — Data & Persistence Lead
// Concrete SwiftData-backed repository implementations.
// All queries use SwiftData #Predicate for type safety.

import Foundation
#if compiler(>=5.9)
import SwiftData
#endif

// MARK: - Task Repository

@MainActor
final class TaskRepository: TaskRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [
                SortDescriptor(\.priorityRaw, order: .reverse),
                SortDescriptor(\.dueDate, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchIncomplete() throws -> [TaskItem] {
        #if compiler(>=5.9)
        let predicate = #Predicate<TaskItem> { !$0.isCompleted }
        var descriptor = FetchDescriptor(predicate: predicate)
        #else
        let all = try fetchAll()
        let filtered = all.filter { !$0.isCompleted }
        var descriptor = FetchDescriptor<TaskItem>()
        // We'll return filtered manually at the end
        #endif
        descriptor.sortBy = [
            SortDescriptor(\.priorityRaw, order: .reverse),
            SortDescriptor(\.dueDate, order: .forward)
        ]
        #if compiler(>=5.9)
        return try modelContext.fetch(descriptor)
        #else
        return filtered
        #endif
    }

    func fetchCompleted() throws -> [TaskItem] {
        #if compiler(>=5.9)
        let predicate = #Predicate<TaskItem> { $0.isCompleted }
        var descriptor = FetchDescriptor(predicate: predicate)
        #else
        let all = try fetchAll()
        let filtered = all.filter { $0.isCompleted }
        var descriptor = FetchDescriptor<TaskItem>()
        #endif
        descriptor.sortBy = [SortDescriptor(\.completedDate, order: .reverse)]
        #if compiler(>=5.9)
        return try modelContext.fetch(descriptor)
        #else
        return filtered
        #endif
    }

    func fetchOverdue() throws -> [TaskItem] {
        let now = Date.now
        #if compiler(>=5.9)
        let distantFuture = Date.distantFuture
        let predicate = #Predicate<TaskItem> { task in
            task.isCompleted == false && (task.dueDate ?? distantFuture) < now
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        #else
        let all = try fetchAll()
        let filtered = all.filter { !$0.isCompleted && $0.dueDate != nil && $0.dueDate! < now }
        var descriptor = FetchDescriptor<TaskItem>()
        #endif
        descriptor.sortBy = [SortDescriptor(\.dueDate, order: .forward)]
        #if compiler(>=5.9)
        return try modelContext.fetch(descriptor)
        #else
        return filtered
        #endif
    }

    func fetchByTag(_ tag: Tag) throws -> [TaskItem] {
        let tagID = tag.id
        #if compiler(>=5.9)
        let predicate = #Predicate<TaskItem> { task in
            task.tags.contains(where: { $0.id == tagID })
        }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
        #else
        let all = try fetchAll()
        return all.filter { task in task.tags.contains(where: { $0.id == tagID }) }
        #endif
    }

    func insert(_ task: TaskItem) throws {
        modelContext.insert(task)
        try save()
    }

    func delete(_ task: TaskItem) throws {
        modelContext.delete(task)
        try save()
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw AppError.persistenceFailed(error.localizedDescription)
        }
    }
}

// MARK: - Note Repository

@MainActor
final class NoteRepository: NoteRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [NoteItem] {
        // Sort only by dateModified here. Pinned/unpinned separation is handled
        // by NoteListViewModel's computed properties, avoiding a SortDescriptor
        // on a Bool-backed @Model property which triggers an NSObject overload
        // resolution failure in Swift 5.10+.
        let descriptor = FetchDescriptor<NoteItem>(
            sortBy: [SortDescriptor(\.dateModified, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchPinned() throws -> [NoteItem] {
        #if compiler(>=5.9)
        let predicate = #Predicate<NoteItem> { $0.isPinned }
        var descriptor = FetchDescriptor(predicate: predicate)
        #else
        let all = try fetchAll()
        let filtered = all.filter { $0.isPinned }
        var descriptor = FetchDescriptor<NoteItem>()
        #endif
        descriptor.sortBy = [SortDescriptor(\.dateModified, order: .reverse)]
        #if compiler(>=5.9)
        return try modelContext.fetch(descriptor)
        #else
        return filtered
        #endif
    }

    func search(query: String) throws -> [NoteItem] {
        let lowered = query.lowercased()
        #if compiler(>=5.9)
        let predicate = #Predicate<NoteItem> { note in
            note.title.localizedStandardContains(lowered) ||
            note.content.localizedStandardContains(lowered)
        }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
        #else
        let all = try fetchAll()
        return all.filter { $0.title.lowercased().contains(lowered) || $0.content.lowercased().contains(lowered) }
        #endif
    }

    func fetchByTag(_ tag: Tag) throws -> [NoteItem] {
        let tagID = tag.id
        #if compiler(>=5.9)
        let predicate = #Predicate<NoteItem> { note in
            note.tags.contains(where: { $0.id == tagID })
        }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
        #else
        let all = try fetchAll()
        return all.filter { note in note.tags.contains(where: { $0.id == tagID }) }
        #endif
    }

    func insert(_ note: NoteItem) throws {
        modelContext.insert(note)
        try save()
    }

    func delete(_ note: NoteItem) throws {
        modelContext.delete(note)
        try save()
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw AppError.persistenceFailed(error.localizedDescription)
        }
    }
}

// MARK: - Calendar Event Repository

@MainActor
final class CalendarEventRepository: CalendarEventRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchEvents(from startDate: Date, to endDate: Date) throws -> [CalendarEvent] {
        #if compiler(>=5.9)
        let predicate = #Predicate<CalendarEvent> { event in
            event.startDate >= startDate && event.startDate <= endDate
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        #else
        let all = try fetchAll()
        let filtered = all.filter { $0.startDate >= startDate && $0.startDate <= endDate }
        var descriptor = FetchDescriptor<CalendarEvent>()
        #endif
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
        #if compiler(>=5.9)
        return try modelContext.fetch(descriptor)
        #else
        return filtered
        #endif
    }

    func fetchEventsForDay(_ date: Date) throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return try fetchEvents(from: startOfDay, to: endOfDay)
    }

    func insert(_ event: CalendarEvent) throws {
        modelContext.insert(event)
        try save()
    }

    func delete(_ event: CalendarEvent) throws {
        modelContext.delete(event)
        try save()
    }

    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw AppError.persistenceFailed(error.localizedDescription)
        }
    }
}
