// Compatibility.swift
// Stubs for SwiftData types when building on older Xcode versions.

import Foundation

#if compiler(<5.9)

import SwiftUI

extension View {
    func modelContainer(_ container: ModelContainer) -> some View {
        self
    }
}

// MARK: - SwiftData Stubs

struct ModelConfiguration {
    init(_ name: String? = nil, schema: Schema? = nil, isStoredInMemoryOnly: Bool = false) {}
}

struct Schema {
    init(_ models: [Any.Type]) {}
}

class ModelContainer {
    var mainContext: ModelContext { ModelContext() }
    static func `for`(_ models: [Any.Type]) throws -> ModelContainer { ModelContainer() }
    init(for schema: Schema, configurations: [ModelConfiguration] = []) throws {}
    init() {}
}

class ModelContext {
    private static var storage: [Any] = []

    func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        return Self.storage.compactMap { $0 as? T }
    }

    func insert<T>(_ model: T) {
        Self.storage.append(model)
    }

    func delete<T>(_ model: T) {
        Self.storage.removeAll { ($0 as? AnyObject) === (model as? AnyObject) }
    }

    func save() throws {}

    static func clearSharedStorage() {
        storage = []
    }
}

struct FetchDescriptor<T> {
    var sortBy: [SortDescriptor<T>] = []
    init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) {
        self.sortBy = sortBy
    }
}

struct SortDescriptor<T> {
    init<Value>(_ keyPath: KeyPath<T, Value>, order: SortOrder = .forward) {}
}

enum SortOrder {
    case forward
    case reverse
}

struct Predicate<T> {
    // Basic stub for predicate
}

// Global function stub for #Predicate
// Note: We can't actually define #Predicate as a macro in Xcode 14, 
// so we'll have to wrap the usage in #if canImport(SwiftData) in the code.

#endif
