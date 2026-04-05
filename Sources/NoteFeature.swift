// NoteFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Notes list with search, pinning, and a rich editor.
// Design: Stitch design tokens applied throughout.

import SwiftUI

// MARK: - Note List ViewModel

@MainActor
final class NoteListViewModel: ObservableObject {
    @Published private(set) var notes: [NoteItem] = []
    @Published private(set) var state: LoadingState<[NoteItem]> = .idle
    @Published var searchText: String = ""
    @Published var sortOption: NoteSortOption = .lastModified

    private let noteRepository: NoteRepositoryProtocol
    private let searchService: SearchServiceProtocol
    private let debouncer = Debouncer()

    init(
        noteRepository: NoteRepositoryProtocol,
        searchService: SearchServiceProtocol
    ) {
        self.noteRepository = noteRepository
        self.searchService = searchService
    }

    deinit {
        #if DEBUG
        print("NoteListViewModel deinitialized")
        #endif
    }

    var pinnedNotes: [NoteItem] {
        sortedNotes.filter(\.isPinned)
    }

    var unpinnedNotes: [NoteItem] {
        sortedNotes.filter { !$0.isPinned }
    }

    private var sortedNotes: [NoteItem] {
        var result = notes

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .lastModified:
            result.sort { $0.dateModified > $1.dateModified }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dateCreated:
            result.sort { $0.dateCreated > $1.dateCreated }
        }

        return result
    }

    func load() async {
        state = .loading
        do {
            notes = try noteRepository.fetchAll()
            state = .loaded(notes)
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func togglePin(for note: NoteItem) async {
        note.isPinned.toggle()
        note.touch()
        do {
            try noteRepository.save()
            await load()
        } catch {
            state = .failed(error as? AppError ?? .unknown(error.localizedDescription))
        }
    }

    func deleteNote(_ note: NoteItem) async {
        do {
            try noteRepository.delete(note)
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

// MARK: - Note Editor ViewModel

@MainActor
final class NoteEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var content: String
    @Published private(set) var isSaving: Bool = false

    let isNewNote: Bool
    private let note: NoteItem?
    private let noteRepository: NoteRepositoryProtocol

    init(note: NoteItem?, noteRepository: NoteRepositoryProtocol) {
        self.note = note
        self.noteRepository = noteRepository
        self.isNewNote = (note == nil)
        self.title = note?.title ?? ""
        self.content = note?.content ?? ""
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var characterCount: Int {
        content.count
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() async throws {
        guard isValid else {
            throw AppError.validationFailed("Note title cannot be empty.")
        }

        isSaving = true
        defer { isSaving = false }

        if let existing = note {
            existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.content = content
            existing.touch()
            try noteRepository.save()
        } else {
            let newNote = NoteItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content
            )
            try noteRepository.insert(newNote)
        }
    }

    func autoSave() {
        guard let existing = note, !isSaving else { return }
        existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        existing.content = content
        existing.touch()
        try? noteRepository.save()
    }
}

// MARK: - Note List View

struct NoteListView: View {
    @ObservedObject var viewModel: NoteListViewModel
    @State private var showingNewNote = false
    @State private var selectedNote: NoteItem?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView("Loading notes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    noteListContent

                case .failed(let error):
                    ErrorBanner(error: error) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Create new note")
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker("Sort By", selection: $viewModel.sortOption) {
                            ForEach(NoteSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search notes")
            #if compiler(>=5.9)
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.searchChanged(newValue)
            }
            #else
            .onChange(of: viewModel.searchText) { newValue in
                viewModel.searchChanged(newValue)
            }
            #endif
            .sheet(isPresented: $showingNewNote) {
                Task { await viewModel.load() }
            } content: {
                NoteEditorSheet(
                    viewModel: DependencyContainer.shared.makeNoteEditorViewModel(note: nil)
                )
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorSheet(
                    viewModel: DependencyContainer.shared.makeNoteEditorViewModel(note: note)
                )
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var noteListContent: some View {
        if viewModel.pinnedNotes.isEmpty && viewModel.unpinnedNotes.isEmpty {
            EmptyStateView(
                icon: "note.text",
                title: "No Notes Yet",
                subtitle: "Tap + to start writing",
                actionTitle: "New Note"
            ) {
                showingNewNote = true
            }
        } else {
            List {
                if !viewModel.pinnedNotes.isEmpty {
                    Section {
                        ForEach(viewModel.pinnedNotes, id: \.id) { note in
                            NoteRowView(note: note)
                                .onTapGesture { selectedNote = note }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task { await viewModel.togglePin(for: note) }
                                    } label: {
                                        Label("Unpin", systemImage: "pin.slash")
                                    }
                                    .tint(.orange)
                                }
                        }
                    } header: {
                        Label("Pinned", systemImage: "pin.fill")
                            .sectionHeader()
                    }
                }

                Section {
                    ForEach(viewModel.unpinnedNotes, id: \.id) { note in
                        NoteRowView(note: note)
                            .onTapGesture { selectedNote = note }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await viewModel.togglePin(for: note) }
                                } label: {
                                    Label("Pin", systemImage: "pin")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteNote(note) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Notes")
                        .sectionHeader()
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await viewModel.load() }
        }
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: NoteItem

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Pinned")
                }
            }

            if !note.previewText.isEmpty {
                Text(note.previewText)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack {
                Text(note.dateModified.relativeDisplay)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text("·")
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text("\(note.wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Spacer()

                if !note.tags.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(note.tags.prefix(2), id: \.id) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isContentFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title", text: $viewModel.title)
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .accessibilityLabel("Note title")

                Divider()
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)

                TextEditor(text: $viewModel.content)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .focused($isContentFocused)
                    .accessibilityLabel("Note content")

                Divider()

                HStack {
                    Text("\(viewModel.wordCount) words")
                    Text("·")
                    Text("\(viewModel.characterCount) characters")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .navigationTitle(viewModel.isNewNote ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            .onAppear {
                if viewModel.isNewNote {
                    isContentFocused = true
                }
            }
        }
    }
}

extension NoteItem: Identifiable {}
