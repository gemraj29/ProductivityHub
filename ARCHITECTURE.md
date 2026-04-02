# Architecture — ProductivityHub

ProductivityHub is built on **Clean Architecture** with **MVVM** at the presentation layer and a **Coordinator** (tab-based `RootCoordinatorView`) managing navigation. Every layer depends inward; the UI never talks to persistence directly.

---

## Layer Overview

```
┌──────────────────────────────────────────┐
│            Presentation Layer            │
│  SwiftUI Views  ←→  ViewModels           │
│  (DashboardView, TaskListView, …)        │
│        ↓ calls ↑ publishes state         │
├──────────────────────────────────────────┤
│              Domain Layer                │
│  Repository Protocols  +  Services       │
│  (TaskRepositoryProtocol, SearchService) │
│        ↓ implemented by                  │
├──────────────────────────────────────────┤
│               Data Layer                 │
│  SwiftData Repositories                  │
│  (TaskRepository, NoteRepository, …)     │
│        ↓ persists via                    │
├──────────────────────────────────────────┤
│            SwiftData / SQLite            │
└──────────────────────────────────────────┘
```

---

## Dependency Injection

`DependencyContainer` is a `@MainActor` singleton that owns the `ModelContainer` and all repositories/services. It exposes `make*` factory methods; the root view calls these once at launch and stores the results in `@StateObject`.

```swift
// App entry point
RootCoordinatorView(container: .shared)

// Inside DependencyContainer
func makeTaskListViewModel() -> TaskListViewModel {
    TaskListViewModel(taskRepository: taskRepository,
                      notificationService: notificationService)
}
```

Nothing outside `DependencyContainer` instantiates a repository or service directly. This makes unit testing trivial — swap a real repository for a mock by passing a different `ModelContext`.

---

## Data Flow

```
User taps button
    → View calls ViewModel method
        → ViewModel calls Repository (async / throws)
            → Repository reads/writes ModelContext
        ← Repository returns model objects
    ← ViewModel updates @Published state
← SwiftUI re-renders View automatically
```

All ViewModels are `@MainActor` — they publish to `@Published` properties which drive SwiftUI updates. Async operations use `async let` for concurrent fetches:

```swift
async let tasks  = taskRepository.fetchIncomplete()
async let events = eventRepository.fetchEventsForDay(.now)
let (t, e) = try await (tasks, events)
```

---

## State Machine

Every ViewModel that fetches remote/async data uses a typed `LoadingState<T>` enum to prevent impossible UI states:

```swift
enum LoadingState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(AppError)
}
```

Views exhaustively switch over all cases — no hidden nil-state bugs.

---

## SwiftData Details

| Topic | Approach |
|---|---|
| **Schema** | `Schema([TaskItem.self, NoteItem.self, CalendarEvent.self, Tag.self])` |
| **Migration** | New optional columns (`workspaceRaw?`, `categoryRaw?`) enable lightweight migration; existing rows get `nil` → computed accessors return safe defaults |
| **Context** | One `mainContext` for the app; tests use `ModelContext(container)` (non-main-actor, in-memory store) |
| **#Predicate safety** | No `!`, no `>=`/`<=` on `Date` (crashes in-memory store); complex filters done in-memory after `fetchAll()` |

---

## Design System

All visual constants live in `DesignSystem.swift` under `DesignTokens`:

| Token group | Examples |
|---|---|
| `Colors` | `accent` (#2865E0), `backgroundNavy` (#0E1E32), `textPrimary/Secondary/Tertiary` |
| `Spacing` | `xxs` (2), `xs` (4), `sm` (8), `md` (12), `lg` (16), `xl` (24), `xxl` (32), `xxxl` (48) |
| `Radius` | `sm` (8), `md` (12), `lg` (16), `xl` (24) |
| `Typography` | `.sectionLabel()`, `.sectionHeader()` view modifiers |

Shared components: `DSCard`, `DSAppHeader`, `DSStatCard`, `DSPriorityDot`, `DSWorkspaceBadge`, `DSProgressRing`.

---

## Feature Modules

Each feature is a single Swift file containing the ViewModel + all its Views.

| File | ViewModel | Key Views |
|---|---|---|
| `DashboardFeature.swift` | `DashboardViewModel` | `DashboardView`, `UpNextTaskRow`, `TimelineEventRow` |
| `TaskFeature.swift` | `TaskListViewModel`, `TaskDetailViewModel` | `TaskListView`, `WorkspaceSection`, `TaskRowView`, `TaskDetailSheet` |
| `NoteFeature.swift` | `NoteListViewModel`, `NoteEditorViewModel` | `NoteListView`, `NoteEditorView` |
| `CalendarFeature.swift` | `CalendarHubViewModel` | `CalendarHubView` |
| `StatsFeature.swift` | `StatsViewModel` | `StatsView` (Swift Charts bar chart) |
| `SettingsFeature.swift` | — | `SettingsView` (AppStorage-driven) |

---

## Navigation

`RootCoordinatorView` owns the `TabView` and the four main ViewModels as `@StateObject`. A custom `DeepSeaTabBar` replaces the native tab bar:

```
[Home] [Tasks] [⊕ Add] [Stats] [Settings]
                  ↑
         Floating action button
         opens TaskDetailSheet
```

`.toolbar(.hidden, for: .tabBar)` hides the native bar; `.safeAreaInset(edge: .bottom)` insets the custom bar above the home indicator.

---

## Testing

**42 unit tests** across 9 test classes, all in `Tests/ProductivityHubTests.swift`.

| Class | What it covers |
|---|---|
| `TaskRepositoryTests` | CRUD + overdue predicate |
| `TaskListViewModelTests` | load, toggle completion, filter, search, delete |
| `TaskDetailViewModelTests` | validation, create, edit, empty-title guard |
| `NoteRepositoryTests` | CRUD + pin + search |
| `NoteListViewModelTests` | load, pin/unpin, delete |
| `NoteEditorViewModelTests` | validation, word count, save, edit |
| `CalendarHubViewModelTests` | load by day, create, delete, date selection, validation |
| `ModelTests` | markCompleted, markIncomplete, word count, preview text, duration |
| `SearchServiceTests` | case-insensitive match, empty query |

**Test infrastructure rules:**
- `makeTestModelContext()` returns a `ModelContext(container)` (non-`@MainActor`, in-memory) so repository calls don't need main-actor dispatch.
- ViewModel test methods are individually annotated `@MainActor` — XCTest properly dispatches them.
- `setUp` uses `setUpWithError()` (not `setUp() throws`) to match XCTestCase's override signature.
- No real network, no file I/O, no `sleep` in any test.

---

## CI/CD

`.github/workflows/swift.yml` runs on every push/PR to `main`:

1. `macos-15` + Xcode 16.2
2. **Build** step (catches compile errors fast)
3. **Test** step (xcodebuild test, JUnit XML output)
4. Artifact upload (test-results.xml, 30-day retention)
5. Concurrency group cancels stale runs on new push
