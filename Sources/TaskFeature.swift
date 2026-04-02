// TaskFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Daily Flow: workspace-grouped task list, redesigned task editor.

import SwiftUI

// MARK: - Task List ViewModel

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published private(set) var tasks:        [TaskItem]               = []
    @Published private(set) var overdueTasks: [TaskItem]               = []
    @Published private(set) var state:        LoadingState<[TaskItem]>  = .idle
    @Published var sortOption:         TaskSortOption = .dueDate
    @Published var showCompletedTasks: Bool           = false
    @Published var searchText:         String         = ""
    @Published var isFocusModeActive:  Bool           = false

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

// MARK: - Task List View

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
                        ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded:
                        taskContent
                    case .failed(let error):
                        VStack { Spacer(); ErrorBanner(error: error) { Task { await viewModel.load() } }; Spacer() }
                    }
                }
                if viewModel.isFocusModeActive {
                    FocusModeBanner { viewModel.isFocusModeActive = false }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingNewTask) { Task { await viewModel.load() } } content: {
                TaskDetailSheet(viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: nil))
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(viewModel: DependencyContainer.shared.makeTaskDetailViewModel(task: task))
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var taskContent: some View {
        if viewModel.filteredTasks.isEmpty {
            EmptyStateView(icon: "checklist", title: "No Tasks Yet",
                           subtitle: "Tap + to create your first task", actionTitle: "Add Task") {
                showingNewTask = true
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    pageHeader.padding(.top, DesignTokens.Spacing.sm)
                    if !viewModel.overdueTasks.isEmpty { overdueBanner }
                    ForEach(viewModel.tasksByWorkspace, id: \.workspace) { group in
                        WorkspaceSection(
                            workspace: group.workspace, tasks: group.tasks,
                            onToggle: { t in Task { await viewModel.toggleCompletion(for: t) } },
                            onSelect: { t in selectedTask = t },
                            onDelete: { t in Task { await viewModel.deleteTask(t) } }
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, viewModel.isFocusModeActive ? 100 : DesignTokens.Spacing.xxxl)
            }
            .refreshable { await viewModel.load() }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Daily Flow")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text("You have \(viewModel.activeCount) active task\(viewModel.activeCount == 1 ? "" : "s") across \(viewModel.tasksByWorkspace.count) workspace\(viewModel.tasksByWorkspace.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            HStack(spacing: 0) {
                filterPill(title: "Active",    isOn: !viewModel.showCompletedTasks) { viewModel.showCompletedTasks = false }
                filterPill(title: "Completed", isOn:  viewModel.showCompletedTasks) { viewModel.showCompletedTasks = true  }
            }
            .padding(3)
            .background(DesignTokens.Colors.backgroundCard, in: Capsule())
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.top, DesignTokens.Spacing.sm)
            .fixedSize()
        }
    }

    private func filterPill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? .white : DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(isOn ? DesignTokens.Colors.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var overdueBanner: some View {
        DSCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(DesignTokens.Colors.destructive)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.overdueTasks.count) Overdue Task\(viewModel.overdueTasks.count == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("These tasks have passed their due date")
                        .font(.caption).foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.overdueTasks.count) overdue tasks")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            DSAppHeader(title: "Productivity", showSearch: true) {}
                .frame(maxWidth: .infinity)
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Picker("Sort By", selection: $viewModel.sortOption) {
                    ForEach(TaskSortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Divider()
                Button {
                    withAnimation { viewModel.isFocusModeActive.toggle() }
                } label: {
                    Label(viewModel.isFocusModeActive ? "Exit Focus Mode" : "Enter Focus Mode", systemImage: "moon.fill")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .accessibilityLabel("Sort and filter")
        }
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
                Image(systemName: workspace.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.workspaceColor(workspace))
                Text(workspace.rawValue)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("\(tasks.count) Task\(tasks.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.sm).padding(.vertical, 3)
                    .background(DesignTokens.Colors.backgroundCard, in: Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 4)
            }
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(tasks, id: \.id) { task in
                    TaskRowView(task: task, onToggle: { onToggle(task) }, onSelect: { onSelect(task) })
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

// MARK: - Task Row View

struct TaskRowView: View {
    let task:     TaskItem
    let onToggle: () -> Void
    let onSelect: () -> Void

    var body: some View {
        DSCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                DSPriorityDot(priority: task.priority, size: 9)

                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                task.isCompleted ? DesignTokens.Colors.success : DesignTokens.Colors.priorityColor(task.priority).opacity(0.5),
                                lineWidth: 1.5
                            )
                            .frame(width: 24, height: 24)
                            .background(task.isCompleted ? DesignTokens.Colors.success.opacity(0.12) : Color.clear, in: Circle())
                        if task.isCompleted {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.success)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: task.isCompleted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(task.title)
                            .font(.callout.weight(.medium))
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            if let due = task.dueDate {
                                Label(due.relativeDisplay, systemImage: "clock").font(.caption)
                                    .foregroundStyle(due.isOverdue && !task.isCompleted ? DesignTokens.Colors.destructive : DesignTokens.Colors.textTertiary)
                            }
                            ForEach(task.tags.prefix(2), id: \.id) { TagChip(tag: $0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit: \(task.title)")

                if task.category != .general {
                    Text(task.category.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .padding(.horizontal, DesignTokens.Spacing.sm).padding(.vertical, 3)
                        .background(DesignTokens.Colors.accentLight, in: Capsule())
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
}

// MARK: - Focus Mode Banner

private struct FocusModeBanner: View {
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "moon.fill").foregroundStyle(DesignTokens.Colors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Mode").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text("Scheduled for the next 2 hours").font(.caption).foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Exit focus mode")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundNavy, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .shadow(color: DesignTokens.Colors.backgroundNavy.opacity(0.4), radius: 16, x: 0, y: -4)
    }
}

// MARK: - Task Detail Sheet

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
                        titleSection; descriptionSection; dueDateSection; prioritySection; categorySection
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            }
            .background(DesignTokens.Colors.backgroundApp)
            .navigationTitle("Task Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isNewTask ? "Add" : "Save") {
                        Task {
                            do { try await viewModel.save(); dismiss() }
                            catch { errorMessage = error.localizedDescription; showError = true }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(
                        (viewModel.isValid && !viewModel.isSaving) ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary,
                        in: Capsule()
                    )
                }
            }
            .alert("Error", isPresented: $showError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [DesignTokens.Colors.backgroundNavy, DesignTokens.Colors.accent.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 140)
                .overlay(
                    Image(systemName: "leaf.fill").font(.system(size: 70))
                        .foregroundStyle(.white.opacity(0.06))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 20)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKFLOW DETAIL").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).kerning(1)
                Text("Refine your focus.").font(.title2.weight(.bold)).foregroundStyle(.white)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .accessibilityHidden(true)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Task Title").sectionLabel()
            DSCard { TextField("Enter task name…", text: $viewModel.title).font(.body).padding(DesignTokens.Spacing.md) }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Description").sectionLabel()
            DSCard {
                TextField("Describe the steps or objectives…", text: $viewModel.description, axis: .vertical)
                    .font(.body).lineLimit(4...8).padding(DesignTokens.Spacing.md)
            }
        }
    }

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("Due Date", systemImage: "calendar").sectionLabel()
            DSCard {
                VStack(spacing: 0) {
                    Toggle("Set Due Date", isOn: $viewModel.hasDueDate.animation())
                        .font(.subheadline).tint(DesignTokens.Colors.accent).padding(DesignTokens.Spacing.md)
                    if viewModel.hasDueDate {
                        Divider()
                        DatePicker("Due", selection: Binding(get: { viewModel.dueDate ?? .now }, set: { viewModel.dueDate = $0 }),
                                   in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical).tint(DesignTokens.Colors.accent)
                            .padding(.horizontal, DesignTokens.Spacing.md).padding(.bottom, DesignTokens.Spacing.sm)
                    }
                }
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("Priority", systemImage: "exclamationmark").sectionLabel()
            DSCard {
                VStack(spacing: 0) {
                    ForEach([Priority.low, .medium, .high], id: \.self) { level in
                        if level != .low { Divider().padding(.leading, DesignTokens.Spacing.lg) }
                        PriorityRadioRow(level: level, isSelected: viewModel.priority == level) { viewModel.priority = level }
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("Category", systemImage: "folder").sectionLabel()
            DSCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("Category").font(.subheadline).foregroundStyle(DesignTokens.Colors.textPrimary)
                        Spacer()
                        Picker("", selection: $viewModel.category) {
                            ForEach(TaskCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.tint(DesignTokens.Colors.accent)
                    }.padding(DesignTokens.Spacing.md)
                    Divider().padding(.leading, DesignTokens.Spacing.md)
                    HStack {
                        Text("Workspace").font(.subheadline).foregroundStyle(DesignTokens.Colors.textPrimary)
                        Spacer()
                        Picker("", selection: $viewModel.workspace) {
                            ForEach(TaskWorkspace.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.tint(DesignTokens.Colors.accent)
                    }.padding(DesignTokens.Spacing.md)
                }
            }
        }
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
                Text(level.label).font(.subheadline).foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                ZStack {
                    Circle().strokeBorder(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected { Circle().fill(DesignTokens.Colors.accent).frame(width: 10, height: 10) }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            .padding(DesignTokens.Spacing.md)
            .background(isSelected ? DesignTokens.Colors.accentLight : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.label) priority")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - TaskItem Identifiable

extension TaskItem: Identifiable {}
