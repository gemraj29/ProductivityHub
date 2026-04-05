// TaskFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Daily Flow: workspace-grouped task list + task editor matching Stitch designs.

import SwiftUI

// MARK: - Task List ViewModel

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks:        [TaskItem]              = []
    @Published private(set) var overdueTasks: [TaskItem]              = []
    @Published private(set) var state:        LoadingState<[TaskItem]> = .idle
    @Published var sortOption:         TaskSortOption = .dueDate
    @Published var showCompletedTasks: Bool           = false
    @Published var searchText:         String         = ""

    private let taskRepository:      TaskRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let debouncer            = Debouncer()

    init(taskRepository: TaskRepositoryProtocol, notificationService: NotificationServiceProtocol) {
        self.taskRepository      = taskRepository
        self.notificationService = notificationService
    }

    deinit {
        #if DEBUG
        print("TaskListViewModel deinitialized")
        #endif
    }

    // MARK: Computed

    var filteredTasks: [TaskItem] {
        var result = tasks
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !showCompletedTasks { result = result.filter { !$0.isCompleted } }
        switch sortOption {
        case .dueDate:     result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .priority:    result.sort { $0.priority > $1.priority }
        case .title:       result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dateCreated: result.sort { $0.dateCreated > $1.dateCreated }
        }
        return result
    }

    var tasksByWorkspace: [(workspace: TaskWorkspace, tasks: [TaskItem])] {
        TaskWorkspace.allCases.compactMap { ws in
            let group = filteredTasks.filter { $0.workspace == ws }
            return group.isEmpty ? nil : (ws, group)
        }
    }

    var completedCount: Int { tasks.filter(\.isCompleted).count }
    var totalCount:     Int { tasks.count }
    var activeCount:    Int { tasks.filter { !$0.isCompleted }.count }

    // MARK: Load

    func load() async {
        state = .loading
        do {
            tasks        = try taskRepository.fetchAll()
            overdueTasks = try taskRepository.fetchOverdue()
            state        = .loaded(tasks)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func toggleCompletion(for task: TaskItem) async {
        if task.isCompleted { task.markIncomplete() } else {
            task.markCompleted()
            await notificationService.cancelReminder(for: task.id)
        }
        do { try taskRepository.save(); await load() }
        catch { state = .failed(error as? AppError ?? .unknown(error.localizedDescription)) }
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
        debouncer.debounce { [weak self] in await self?.load() }
    }
}

// MARK: - Task Detail ViewModel

@MainActor
final class TaskDetailViewModel: ObservableObject {
    @Published var title:       String
    @Published var description: String
    @Published var priority:    Priority
    @Published var workspace:   TaskWorkspace
    @Published var category:    TaskCategory
    @Published var dueDate:     Date?
    @Published var hasDueDate:  Bool
    @Published private(set) var isSaving: Bool = false

    let isNewTask: Bool
    private let task:           TaskItem?
    private let taskRepository: TaskRepositoryProtocol

    init(task: TaskItem?, taskRepository: TaskRepositoryProtocol) {
        self.task           = task
        self.taskRepository = taskRepository
        self.isNewTask      = (task == nil)
        self.title          = task?.title           ?? ""
        self.description    = task?.taskDescription ?? ""
        self.priority       = task?.priority        ?? .medium
        self.workspace      = task?.workspace       ?? .inbox
        self.category       = task?.category        ?? .general
        self.dueDate        = task?.dueDate
        self.hasDueDate     = task?.dueDate != nil
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func save() async throws {
        guard isValid else { throw AppError.validationFailed("Task title cannot be empty.") }
        isSaving = true
        defer { isSaving = false }
        if let existing = task {
            existing.title           = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.taskDescription = description
            existing.priority        = priority
            existing.workspace       = workspace
            existing.category        = category
            existing.dueDate         = hasDueDate ? dueDate : nil
            existing.dateModified    = .now
            try taskRepository.save()
        } else {
            let newTask = TaskItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description, priority: priority,
                workspace: workspace, category: category,
                dueDate: hasDueDate ? dueDate : nil
            )
            try taskRepository.insert(newTask)
        }
    }
}

// MARK: - Task List View (Stitch "Daily Flow")

struct TaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @State private var showingNewTask = false
    @State private var selectedTask:  TaskItem?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                Group {
                    switch viewModel.state {
                    case .idle, .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        taskContent
                    case .failed(let error):
                        VStack {
                            Spacer()
                            ErrorBanner(error: error) { Task { await viewModel.load() } }
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity", showSearch: true)
                        .frame(maxWidth: .infinity)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker("Sort By", selection: $viewModel.sortOption) {
                            ForEach(TaskSortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .accessibilityLabel("Sort and filter")
                }
            }
            .sheet(isPresented: $showingNewTask) { Task { await viewModel.load() } } content: {
                TaskDetailSheet(viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: nil))
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: task))
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: Task Content

    @ViewBuilder
    private var taskContent: some View {
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    pageHeader.padding(.top, DesignTokens.Spacing.sm)

                    if !viewModel.overdueTasks.isEmpty {
                        overdueBanner
                    }

                    // Work section (lg col)
                    ForEach(viewModel.tasksByWorkspace, id: \.workspace) { group in
                        WorkspaceSection(
                            workspace: group.workspace,
                            tasks: group.tasks,
                            onToggle: { t in Task { await viewModel.toggleCompletion(for: t) } },
                            onSelect: { t in selectedTask = t },
                            onDelete: { t in Task { await viewModel.deleteTask(t) } }
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable { await viewModel.load() }
        }
    }

    // MARK: Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Daily Flow")
                    .font(.headline(32))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("You have \(viewModel.activeCount) active task\(viewModel.activeCount == 1 ? "" : "s") across \(viewModel.tasksByWorkspace.count) workspace\(viewModel.tasksByWorkspace.count == 1 ? "" : "s").")
                    .font(.body(14))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            // Active / Completed toggle (Stitch style segmented)
            HStack(spacing: 0) {
                filterPill(title: "Active",    isOn: !viewModel.showCompletedTasks) { viewModel.showCompletedTasks = false }
                filterPill(title: "Completed", isOn:  viewModel.showCompletedTasks) { viewModel.showCompletedTasks = true  }
            }
            .padding(3)
            .background(DesignTokens.Colors.surfaceHigh, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
            .fixedSize()
        }
    }

    private func filterPill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body(14, weight: .semibold))
                .foregroundStyle(isOn ? DesignTokens.Colors.primary : DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    isOn ? DesignTokens.Colors.backgroundCard : Color.clear,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                )
                .shadow(color: isOn ? Color.black.opacity(0.06) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var overdueBanner: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DesignTokens.Colors.destructive)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.overdueTasks.count) Overdue Task\(viewModel.overdueTasks.count == 1 ? "" : "s")")
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("These tasks have passed their due date")
                    .font(.body(12))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            DesignTokens.Colors.destructive.opacity(0.06),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .strokeBorder(DesignTokens.Colors.destructive.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.overdueTasks.count) overdue tasks")
    }
}

// MARK: - Workspace Section

private struct WorkspaceSection: View {
    let workspace: TaskWorkspace
    let tasks:     [TaskItem]
    let onToggle:  (TaskItem) -> Void
    let onSelect:  (TaskItem) -> Void
    let onDelete:  (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Stitch color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.workspaceColor(workspace))
                    .frame(width: 4, height: 22)

                Text(workspace.rawValue)
                    .font(.headline(17))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                Text("\(tasks.count) Task\(tasks.count == 1 ? "" : "s")")
                    .font(.label(11, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.onPrimaryFixed)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Colors.primaryFixed, in: Capsule())
            }
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(tasks, id: \.id) { task in
                    TaskRowView(
                        task: task,
                        onToggle: { onToggle(task) },
                        onSelect: { onSelect(task) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(task) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Task Row View (Stitch bordered card with priority left-bar)

struct TaskRowView: View {
    let task:     TaskItem
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left priority border (Stitch: border-l-4 border-tertiary-container)
            RoundedRectangle(cornerRadius: 2)
                .fill(task.priority == .high || task.priority == .urgent
                      ? DesignTokens.Colors.tertiaryContainer
                      : DesignTokens.Colors.outlineVariant.opacity(0.4))
                .frame(width: 4)

            HStack(spacing: DesignTokens.Spacing.md) {
                // Completion button
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                task.isCompleted
                                    ? DesignTokens.Colors.success
                                    : DesignTokens.Colors.outlineVariant,
                                lineWidth: 1.5
                            )
                            .frame(width: 22, height: 22)
                            .background(
                                task.isCompleted ? DesignTokens.Colors.success.opacity(0.12) : Color.clear,
                                in: Circle()
                            )
                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.success)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: task.isCompleted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

                // Task info
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text(task.title)
                                .font(.headline(16))
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(
                                    task.isCompleted
                                        ? DesignTokens.Colors.textSecondary
                                        : DesignTokens.Colors.textPrimary
                                )
                                .lineLimit(1)
                                .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                            PriorityBadge(priority: task.priority)
                        }

                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if let due = task.dueDate {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                Text(due.relativeDisplay)
                                    .font(.body(12))
                                    .foregroundStyle(
                                        due.isOverdue && !task.isCompleted
                                            ? DesignTokens.Colors.destructive
                                            : DesignTokens.Colors.textSecondary
                                    )
                            }
                            ForEach(task.tags.prefix(2), id: \.id) { TagChip(tag: $0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit: \(task.title)")
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 10, x: 0, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
    }
}

// MARK: - Task Detail Sheet (Stitch Task Editor)

struct TaskDetailSheet: View {
    @ObservedObject var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showError    = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroBanner

                    VStack(spacing: DesignTokens.Spacing.xl) {
                        mainFields
                        metaPanel
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl)
                }
            }
            .background(DesignTokens.Colors.backgroundApp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("Task Editor")
                        .font(.headline(17))
                        .foregroundStyle(DesignTokens.Colors.primaryContainer)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isNewTask ? "Add" : "Save") {
                        Task {
                            do { try await viewModel.save(); dismiss() }
                            catch { errorMessage = error.localizedDescription; showError = true }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.onPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs + 2)
                    .background(
                        (viewModel.isValid && !viewModel.isSaving)
                            ? LinearGradient.deepSeaPrimary
                            : LinearGradient(colors: [DesignTokens.Colors.outlineVariant], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                    )
                }
            }
            .alert("Error", isPresented: $showError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }

    // MARK: Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient.deepSeaPrimary
                .frame(height: 160)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.white.opacity(0.05))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                )
            LinearGradient(
                colors: [.black.opacity(0.35), .clear],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("WORKFLOW DETAIL")
                    .font(.label(10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .kerning(1.5)
                Text("Refine your focus.")
                    .font(.headline(26))
                    .foregroundStyle(Color.white)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .accessibilityHidden(true)
    }

    // MARK: Main Fields

    private var mainFields: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // Task Title
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("TASK TITLE")
                    .sectionLabel()
                    .padding(.leading, DesignTokens.Spacing.xs)

                TextField("Enter task name…", text: $viewModel.title)
                    .font(.headline(18))
                    .padding(DesignTokens.Spacing.lg)
                    .background(DesignTokens.Colors.surfaceHighest, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
            }

            // Description
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("DESCRIPTION")
                    .sectionLabel()
                    .padding(.leading, DesignTokens.Spacing.xs)

                TextField("Describe the steps or objectives…", text: $viewModel.description, axis: .vertical)
                    .font(.body(15))
                    .lineLimit(4...8)
                    .padding(DesignTokens.Spacing.lg)
                    .background(DesignTokens.Colors.surfaceHighest, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
            }
        }
    }

    // MARK: Meta Panel (Due Date, Priority, Category)

    private var metaPanel: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            dueDateCard
            priorityCard
            categoryCard
        }
    }

    private var dueDateCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.primary)
                Text("Due Date")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $viewModel.hasDueDate.animation())
                    .labelsHidden()
                    .tint(DesignTokens.Colors.primary)
            }
            .padding(DesignTokens.Spacing.lg)

            if viewModel.hasDueDate {
                Divider().padding(.horizontal, DesignTokens.Spacing.lg)
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
                .tint(DesignTokens.Colors.primary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }
        }
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
    }

    private var priorityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.primary)
                Text("Priority")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.lg)

            Divider().padding(.horizontal, DesignTokens.Spacing.lg)

            VStack(spacing: 0) {
                ForEach([Priority.low, .medium, .high], id: \.self) { level in
                    PriorityRadioRow(
                        level: level,
                        isSelected: viewModel.priority == level,
                        onSelect: { viewModel.priority = level }
                    )
                    if level != .high {
                        Divider().padding(.horizontal, DesignTokens.Spacing.lg)
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
    }

    private var categoryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.primary)
                Text("Category")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Picker("", selection: $viewModel.category) {
                    ForEach(TaskCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .tint(DesignTokens.Colors.primary)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider().padding(.horizontal, DesignTokens.Spacing.lg)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "briefcase")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.primary)
                Text("Workspace")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Picker("", selection: $viewModel.workspace) {
                    ForEach(TaskWorkspace.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .tint(DesignTokens.Colors.primary)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
    }
}

// MARK: - Priority Radio Row

private struct PriorityRadioRow: View {
    let level:      Priority
    let isSelected: Bool
    let onSelect:   () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                DSPriorityDot(priority: level, size: 10)

                Text(level.label)
                    .font(.body(15))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.Colors.primary)
                } else {
                    Circle()
                        .strokeBorder(DesignTokens.Colors.outlineVariant, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(
                isSelected ? DesignTokens.Colors.primaryFixed.opacity(0.5) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel("\(level.label) priority")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - TaskItem Identifiable

extension TaskItem: Identifiable {}
