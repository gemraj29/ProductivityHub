// Models.swift
// Principal Engineer: Rajesh Vallepalli — Data & Persistence Lead
// SwiftData models for Tasks, Notes, Calendar Events, and Tags.

import Foundation
#if compiler(>=5.9)
import SwiftData
#endif

// MARK: - Task Item

#if compiler(>=5.9)
@Model
#endif
final class TaskItem {
    #if compiler(>=5.9)
    @Attribute(.unique)
    #endif
    var id: TaskID
    var title: String
    var taskDescription: String
    var isCompleted: Bool
    var priorityRaw: Int
    var workspaceRaw: String?   // optional for SwiftData lightweight migration
    var categoryRaw: String?    // optional for SwiftData lightweight migration
    var dueDate: Date?
    var completedDate: Date?
    var dateCreated: Date
    var dateModified: Date
    #if compiler(>=5.9)
    @Relationship(deleteRule: .nullify, inverse: \Tag.tasks)
    #endif
    var tags: [Tag]

    // MARK: Computed — type-safe accessors

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var workspace: TaskWorkspace {
        get { workspaceRaw.flatMap { TaskWorkspace(rawValue: $0) } ?? .inbox }
        set { workspaceRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { categoryRaw.flatMap { TaskCategory(rawValue: $0) } ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: TaskID = UUID(),
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        workspace: TaskWorkspace = .inbox,
        category: TaskCategory = .general,
        dueDate: Date? = nil,
        tags: [Tag] = []
    ) {
        self.id              = id
        self.title           = title
        self.taskDescription = description
        self.isCompleted     = isCompleted
        self.priorityRaw     = priority.rawValue
        self.workspaceRaw    = workspace.rawValue   // non-nil for newly created tasks
        self.categoryRaw     = category.rawValue    // existing rows get nil → computed fallback
        self.dueDate         = dueDate
        self.completedDate   = nil
        self.dateCreated     = .now
        self.dateModified    = .now
        self.tags            = tags
    }

    func markCompleted() {
        isCompleted    = true
        completedDate  = .now
        dateModified   = .now
    }

    func markIncomplete() {
        isCompleted   = false
        completedDate = nil
        dateModified  = .now
    }
}

// MARK: - Note Item

#if compiler(>=5.9)
@Model
#endif
final class NoteItem {
    #if compiler(>=5.9)
    @Attribute(.unique)
    #endif
    var id: NoteID
    var title: String
    var content: String
    var isPinned: Bool
    var dateCreated: Date
    var dateModified: Date
    #if compiler(>=5.9)
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    #endif
    var tags: [Tag]

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var previewText: String {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " ")
    }

    init(
        id: NoteID = UUID(),
        title: String = "Untitled Note",
        content: String = "",
        isPinned: Bool = false,
        tags: [Tag] = []
    ) {
        self.id          = id
        self.title       = title
        self.content     = content
        self.isPinned    = isPinned
        self.dateCreated = .now
        self.dateModified = .now
        self.tags        = tags
    }

    func touch() {
        dateModified = .now
    }
}

// MARK: - Calendar Event

#if compiler(>=5.9)
@Model
#endif
final class CalendarEvent {
    #if compiler(>=5.9)
    @Attribute(.unique)
    #endif
    var id: EventID
    var title: String
    var eventDescription: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var colorHex: String
    var dateCreated: Date
    #if compiler(>=5.9)
    @Relationship(deleteRule: .nullify, inverse: \Tag.events)
    #endif
    var tags: [Tag]

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var isMultiDay: Bool {
        !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    init(
        id: EventID = UUID(),
        title: String,
        description: String = "",
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        colorHex: String = "#2865E0",
        tags: [Tag] = []
    ) {
        self.id               = id
        self.title            = title
        self.eventDescription = description
        self.startDate        = startDate
        self.endDate          = endDate
        self.isAllDay         = isAllDay
        self.colorHex         = colorHex
        self.dateCreated      = .now
        self.tags             = tags
    }
}

// MARK: - Tag

#if compiler(>=5.9)
@Model
#endif
final class Tag {
    #if compiler(>=5.9)
    @Attribute(.unique)
    #endif
    var id: TagID
    var name: String
    var colorHex: String
    var tasks: [TaskItem]
    var notes: [NoteItem]
    var events: [CalendarEvent]

    init(
        id: TagID = UUID(),
        name: String,
        colorHex: String = "#2865E0"
    ) {
        self.id       = id
        self.name     = name
        self.colorHex = colorHex
        self.tasks    = []
        self.notes    = []
        self.events   = []
    }
}
