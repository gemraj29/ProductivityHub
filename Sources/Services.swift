// Services.swift
// Principal Engineer: Rajesh Vallepalli — Platform & Performance Lead
// Notification scheduling, search highlighting, and caching infrastructure.
// All services are protocol-conformant and Sendable.

import Foundation
import UserNotifications

// MARK: - Notification Service

final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleTaskReminder(for task: TaskItem) async throws {
        guard let dueDate = task.dueDate else { return }

        let authorized = try await requestAuthorization()
        guard authorized else {
            throw AppError.notificationDenied
        }

        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskID": task.id.uuidString]

        // Schedule 15 minutes before due date
        let triggerDate = dueDate.addingTimeInterval(-15 * 60)
        guard triggerDate > .now else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelReminder(for taskID: TaskID) async {
        center.removePendingNotificationRequests(
            withIdentifiers: ["task-\(taskID.uuidString)"]
        )
    }
}

// MARK: - Search Service

final class SearchService: SearchServiceProtocol, Sendable {
    func highlightMatches(
        in text: String,
        query: String
    ) -> [(range: Range<String.Index>, text: String)] {
        guard !query.isEmpty else { return [] }

        var results: [(range: Range<String.Index>, text: String)] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            results.append((range: range, text: String(text[range])))
            searchRange = range.upperBound..<text.endIndex
        }

        return results
    }
}

// MARK: - Image Cache (NSCache-backed, auto-evicts)

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, CacheEntry>()

    private final class CacheEntry {
        let data: Data
        let timestamp: Date

        init(data: Data) {
            self.data = data
            self.timestamp = .now
        }
    }

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func data(forKey key: String) -> Data? {
        cache.object(forKey: key as NSString)?.data
    }

    func setData(_ data: Data, forKey key: String) {
        let entry = CacheEntry(data: data)
        cache.setObject(entry, forKey: key as NSString, cost: data.count)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Debouncer (for search input)

@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let duration: Duration

    init(duration: Duration = .milliseconds(300)) {
        self.duration = duration
    }

    func debounce(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    deinit {
        task?.cancel()
    }
}
