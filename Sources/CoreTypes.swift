// CoreTypes.swift
// Principal Engineer: Sofia Chen — Chief Architect
// Shared types used across all modules.

import Foundation

// MARK: - Loading State Machine

enum LoadingState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(AppError)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }
}

// MARK: - App-Wide Errors

enum AppError: LocalizedError, Sendable {
    case persistenceFailed(String)
    case validationFailed(String)
    case notFound(String)
    case notificationDenied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .persistenceFailed(let detail):
            return "Could not save your data: \(detail)"
        case .validationFailed(let detail):
            return "Invalid input: \(detail)"
        case .notFound(let entity):
            return "\(entity) not found."
        case .notificationDenied:
            return "Notifications are disabled. Enable them in Settings to receive reminders."
        case .unknown(let detail):
            return "Something went wrong: \(detail)"
        }
    }
}

// MARK: - Typealiases for Semantic Clarity

typealias TaskID = UUID
typealias NoteID = UUID
typealias EventID = UUID
typealias TagID = UUID

// MARK: - Priority Levels

enum Priority: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .urgent: return "Urgent"
        }
    }

    var iconName: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Sort Options

enum TaskSortOption: String, CaseIterable, Sendable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case title = "Title"
    case dateCreated = "Date Created"
}

enum NoteSortOption: String, CaseIterable, Sendable {
    case lastModified = "Last Modified"
    case title = "Title"
    case dateCreated = "Date Created"
}

// MARK: - Date Helpers

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isTomorrow: Bool { Calendar.current.isDateInTomorrow(self) }
    var isOverdue: Bool { self < Date.now && !isToday }

    var relativeDisplay: String {
        if isToday { return "Today" }
        if isTomorrow { return "Tomorrow" }
        if isOverdue { return "Overdue" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
