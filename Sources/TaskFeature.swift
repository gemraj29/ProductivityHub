// TaskFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Task list, detail, and creation flow.

import SwiftUI

// MARK: - Task List ViewModel

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var overdueTasks: [TaskItem] = []
    @Published private(set) var state: LoadingState<[TaskItem]> = .idle
    @Published var sortOption: TaskSortOption = .dueDate
    @Published var showCompletedTasks: Bool = false
    @Published var searchText: String = ""

    private let taskRepository: TaskRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let debouncer = Debouncer()

    init(
        taskRepository: TaskRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
    }

    deinit {
        // Debug: verify no retain cycles
        #if DEBUG
        print("TaskListViewModel deinitialized")
        #endif
    }

    var filteredTasks: [TaskItem] {
        var result = tasks

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        if !showCompletedTasks {
            result = result.filter { !$0.isCompleted }
        }

        switch sortOption {
        case .dueDate:
            result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .priority:
            result.sort { $0.priority > $1.priority }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dateCreated:
            result.sort { $0.dateCreated > $1.dateCreated }
        }

        return result
    }

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var totalCount: Int {
        tasks.count
    }

    func load() async {
        state = .loading
        do {
            tasks = try taskRepository.fetchAll()
            overdueTasks = try taskRepository.fetchOverdue()
            state = .loaded(tasks)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func toggleCompletion(for task: TaskItem) async {
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markCompleted()
            await notificationService.cancelReminder(for: task.id)
        }
        do {
            try taskRepository.save()
            await load()
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func deleteTask(_ task: TaskItem) async {
        do {
            await notificationService.cancelReminder(for: task.id)
            try taskRepository.delete(task)
            await load()
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func searchChanged(_ query: String) {
        debouncer.debounce { [weak self] in
            await self?.load()
        }
    }
}

// MARK: - Task Detail ViewModel

@MainActor
final class TaskDetailViewModel: ObservableObject {
    @Published var title: String
    @Published var description: String
    @Published var priority: Priority
    @Published var dueDate: Date?
    @Published var hasDueDate: Bool
    @Published private(set) var isSaving: Bool = false

    let isNewTask: Bool
    private let task: TaskItem?
    private let taskRepository: TaskRepositoryProtocol

    init(task: TaskItem?, taskRepository: TaskRepositoryProtocol) {
        self.task = task
        self.taskRepository = taskRepository
        self.isNewTask = (task == nil)
        self.title = task?.title ?? ""
        self.description = task?.taskDescription ?? ""
        self.priority = task?.priority ?? .medium
        self.dueDate = task?.dueDate
        self.hasDueDate = task?.dueDate != nil
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() async throws {
        guard isValid else {
            throw AppError.validationFailed("Task title cannot be empty.")
        }

        isSaving = true
        defer { isSaving = false }

        if let existing = task {
            existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.taskDescription = description
            existing.priority = priority
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.dateModified = .now
        } else {
            let newTask = TaskItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil
            )
            try taskRepository.insert(newTask)
            return
        }

        try taskRepository.save()
    }
}

// MARK: - Task List View

struct TaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @State private var showingNewTask = false
    @State private var selectedTask: TaskItem?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading tasks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    taskListContent

                case .failed(let error):
                    ErrorBanner(error: error) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar { toolbarContent }
            .searchable(text: $viewModel.searchText, prompt: "Search tasks")
            #if compiler(>=5.9)
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.searchChanged(newValue)
            }
            #else
            .onChange(of: viewModel.searchText) { newValue in
                viewModel.searchChanged(newValue)
            }
            #endif
            .sheet(isPresented: $showingNewTask) {
                Task { await viewModel.load() }
            } content: {
                TaskDetailSheet(
                    viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: nil)
                )
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(
                    viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: task)
                )
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Task List Content

    @ViewBuilder
    private var taskListContent: some View {
        if viewModel.filteredTasks.isEmpty {
            EmptyStateView(
                icon: "checklist",
                title: "No Tasks Yet",
                subtitle: "Tap + to create your first task",
                actionTitle: "Add Task"
            ) {
                showingNewTask = true
            }
        } else {
            List {
                if !viewModel.overdueTasks.isEmpty {
                    Section {
                        ForEach(viewModel.overdueTasks, id: \.id) { task in
                            TaskRowView(task: task) {
                                Task { await viewModel.toggleCompletion(for: task) }
                            }
                            .onTapGesture { selectedTask = task }
                        }
                    } header: {
                        Label("Overdue", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.destructive)
                            .sectionHeader()
                    }
                }

                Section {
                    ForEach(viewModel.filteredTasks, id: \.id) { task in
                        TaskRowView(task: task) {
                            Task { await viewModel.toggleCompletion(for: task) }
                        }
                        .onTapGesture { selectedTask = task }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteTask(task) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("All Tasks")
                            .sectionHeader()
                        Spacer()
                        Text("\(viewModel.completedCount)/\(viewModel.totalCount) done")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.load() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingNewTask = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Add new task")
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Picker("Sort By", selection: $viewModel.sortOption) {
                    ForEach(TaskSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }

                Toggle("Show Completed", isOn: $viewModel.showCompletedTasks)
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Sort and filter options")
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignTokens.Colors.success
                            : DesignTokens.Colors.textTertiary
                    )
                    #if compiler(>=5.9)
                    .contentTransition(.symbolEffect(.replace))
                    #endif
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignTokens.Colors.textTertiary
                            : DesignTokens.Colors.textPrimary
                    )

                if let dueDate = task.dueDate {
                    Text(dueDate.relativeDisplay)
                        .font(.caption)
                        .foregroundStyle(
                            dueDate.isOverdue && !task.isCompleted
                                ? DesignTokens.Colors.destructive
                                : DesignTokens.Colors.textSecondary
                        )
                }
            }

            Spacer()

            PriorityBadge(priority: task.priority)

            if !task.tags.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(task.tags.prefix(2), id: \.id) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Task Detail Sheet

struct TaskDetailSheet: View {
    @ObservedObject var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Info") {
                    TextField("Title", text: $viewModel.title)
                        .font(.headline)
                        .accessibilityLabel("Task title")

                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Task description")
                }

                Section("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Label(priority.label, systemImage: priority.iconName)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $viewModel.hasDueDate.animation())

                    if viewModel.hasDueDate {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { viewModel.dueDate ?? .now },
                                set: { viewModel.dueDate = $0 }
                            ),
                            in: Date.now...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .accessibilityLabel("Select due date")
                    }
                }
            }
            .navigationTitle(viewModel.isNewTask ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isNewTask ? "Add" : "Save") {
                        Task {
                            do {
                                try await viewModel.save()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// Make TaskItem identifiable for sheet presentation
extension TaskItem: Identifiable {}
