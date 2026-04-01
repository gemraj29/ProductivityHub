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
            try taskRepository.save()
        } else {
            let newTask = TaskItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil
            )
            try taskRepository.insert(newTask)
        }
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
                    ProgressView("Loading tasks…")
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
        if viewModel.filteredTasks.isEmpty && viewModel.overdueTasks.isEmpty {
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
                // Progress summary card
                if viewModel.totalCount > 0 {
                    Section {
                        TaskProgressCard(
                            completed: viewModel.completedCount,
                            total: viewModel.totalCount
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }

                // Overdue section
                if !viewModel.overdueTasks.isEmpty {
                    Section {
                        ForEach(viewModel.overdueTasks, id: \.id) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { Task { await viewModel.toggleCompletion(for: task) } },
                                onSelect: { selectedTask = task }
                            )
                        }
                    } header: {
                        Label("Overdue", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(DesignTokens.Colors.destructive)
                            .sectionHeader()
                    }
                }

                // All tasks section
                Section {
                    ForEach(viewModel.filteredTasks, id: \.id) { task in
                        TaskRowView(
                            task: task,
                            onToggle: { Task { await viewModel.toggleCompletion(for: task) } },
                            onSelect: { selectedTask = task }
                        )
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
                    .foregroundStyle(DesignTokens.Colors.accent)
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

// MARK: - Task Progress Card

private struct TaskProgressCard: View {
    let completed: Int
    let total: Int

    private var remaining: Int { total - completed }
    private var progress: Double { total == 0 ? 0.0 : Double(completed) / Double(total) }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                    Text("\(remaining)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(remaining == 1 ? "task left" : "tasks left")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .padding(.bottom, 4)
                }
                Text("\(completed) of \(total) complete")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(DesignTokens.Colors.success.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        DesignTokens.Colors.success,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Colors.success)
                    Text("%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.success.opacity(0.8))
                }
            }
            .frame(width: 68, height: 68)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.accent.opacity(0.08),
                    DesignTokens.Colors.success.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .strokeBorder(DesignTokens.Colors.accent.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(remaining) tasks remaining, \(Int(progress * 100)) percent complete")
    }
}

// MARK: - Task Row View
//
// Key fix: the previous implementation applied .onTapGesture to the whole row
// while also containing a Button (the checkmark). In SwiftUI, both gestures
// fire on the same tap — tapping the checkmark would simultaneously toggle
// completion AND open the edit sheet.
//
// Fix: split into two independent Buttons — one for completion toggle
// (the circle), one for editing (the text/detail content). No onTapGesture.

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onSelect: () -> Void

    private var priorityColor: Color {
        DesignTokens.Colors.priorityColor(task.priority)
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {

            // Priority color strip
            Capsule()
                .fill(task.isCompleted ? Color(.tertiarySystemFill) : priorityColor)
                .frame(width: 4)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .animation(.easeInOut(duration: 0.25), value: task.isCompleted)

            // Completion circle — only this button toggles completion
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted
                                ? DesignTokens.Colors.success
                                : priorityColor.opacity(0.55),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            task.isCompleted
                                ? DesignTokens.Colors.success.opacity(0.15)
                                : Color.clear,
                            in: Circle()
                        )

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.success)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            // Task content — only this button opens the editor
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(
                            task.isCompleted
                                ? DesignTokens.Colors.textTertiary
                                : DesignTokens.Colors.textPrimary
                        )
                        .multilineTextAlignment(.leading)
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        if let dueDate = task.dueDate {
                            Label(dueDate.relativeDisplay, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(
                                    dueDate.isOverdue && !task.isCompleted
                                        ? DesignTokens.Colors.destructive
                                        : DesignTokens.Colors.textSecondary
                                )
                        }

                        if !task.tags.isEmpty {
                            HStack(spacing: DesignTokens.Spacing.xxs) {
                                ForEach(task.tags.prefix(2), id: \.id) { tag in
                                    TagChip(tag: tag)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit: \(task.title)")

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
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
                        .tint(DesignTokens.Colors.accent)
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
