//
//  GoalsView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Metas: goals in progress and the history of completed ones.
struct GoalsView: View {
    enum Filter: Hashable {
        case inProgress
        case completed
    }

    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @State private var filter = Filter.inProgress
    @State private var editor: GoalEditorView.Mode?
    @State private var errorMessage: String?
    @FetchRequest private var goals: FetchedResults<Goal>

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        _goals = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Goal.completedAt, ascending: false),
                NSSortDescriptor(keyPath: \Goal.createdAt, ascending: false),
            ],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space),
            animation: .default
        )
    }

    private var filtered: [Goal] {
        goals.filter { ($0.completedAt != nil) == (filter == .completed) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                PillSegmentedControl(selection: $filter, options: [
                    .init(value: .inProgress, title: "Em andamento"),
                    .init(value: .completed, title: "Concluídas"),
                ])
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                let items = filtered
                if items.isEmpty {
                    if filter == .inProgress {
                        EmptyStateView(
                            systemImage: "target",
                            title: "Nenhuma meta em andamento",
                            message: "Viagens, planos e conquistas, com etapas e prazo.",
                            actionTitle: "Nova meta",
                            action: { editor = .create }
                        )
                    } else {
                        EmptyStateView(systemImage: "checkmark.seal", title: "Nenhuma meta concluída", message: "As metas que vocês concluírem ficam guardadas aqui.")
                    }
                } else {
                    LazyVStack(spacing: Spacing.m) {
                        ForEach(items) { goal in
                            GoalCard(
                                goal: goal,
                                onToggle: { step in perform { try environment.goals.toggle(step, by: userRecordName) } },
                                onEdit: { editor = .edit(goal) },
                                onComplete: { perform { try environment.goals.complete(goal, by: userRecordName) } },
                                onReopen: { perform { try environment.goals.reopen(goal, by: userRecordName) } },
                                onDelete: { perform { try environment.goals.softDelete(goal, by: userRecordName) } }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationTitle("Nossos planos")
        .navigationSubtitle("Sonhos que se constroem juntos.")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nova meta", systemImage: "plus") { editor = .create }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("goals.add")
            }
        }
        .sheet(item: $editor) { mode in
            GoalEditorView(environment: environment, space: space, userRecordName: userRecordName, mode: mode)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Creates or edits a goal: title, category, optional due date, cover photo and steps.
struct GoalEditorView: View {
    enum Mode: Identifiable {
        case create
        case edit(Goal)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let goal): goal.objectID.uriRepresentation().absoluteString
            }
        }
    }

    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var draft: GoalDraft
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var newStep = ""
    @State private var errorMessage: String?
    private let initialDraft: GoalDraft

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String, mode: Mode) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.mode = mode
        let draft: GoalDraft
        if case .edit(let goal) = mode {
            draft = environment.goals.draft(for: goal)
        } else {
            draft = GoalDraft()
        }
        initialDraft = draft
        _draft = State(initialValue: draft)
        _hasDueDate = State(initialValue: draft.dueDate != nil)
        _dueDate = State(initialValue: draft.dueDate ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var finalDraft: GoalDraft {
        var result = draft
        result.dueDate = hasDueDate ? dueDate : nil
        let pending = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            result.steps.append(.init(title: pending))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $draft.title)
                        .font(.cardTitle)
                        .accessibilityIdentifier("goalEditor.title")
                    Picker("Categoria", selection: $draft.category) {
                        ForEach(GoalCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                    Toggle("Prazo", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Até", selection: $dueDate, displayedComponents: .date)
                    }
                }
                .listRowBackground(Palette.surface)
                Section {
                    ForEach($draft.steps) { $step in
                        TextField("Etapa", text: $step.title)
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                    HStack {
                        TextField("Nova etapa", text: $newStep)
                            .onSubmit(addStep)
                            .submitLabel(.done)
                            .accessibilityIdentifier("goalEditor.newStep")
                        Button("Adicionar etapa", systemImage: "plus.circle.fill", action: addStep)
                            .labelStyle(.iconOnly)
                            .disabled(newStep.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Etapas")
                } footer: {
                    Text("O progresso é calculado pelas etapas feitas. Deslize para remover.")
                }
                .listRowBackground(Palette.surface)
                Section("Foto") {
                    HStack(spacing: Spacing.m) {
                        DecodedImage(data: draft.coverPhotoData) {
                            Image(systemName: draft.category.systemImage)
                                .foregroundStyle(Palette.accentText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Palette.surfaceMuted)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            PhotoPickerButton(onPicked: { draft.coverPhotoData = $0.thumbnailData }, onFailure: { errorMessage = $0 }) {
                                Text(draft.coverPhotoData == nil ? "Escolher foto" : "Trocar foto")
                            }
                            if draft.coverPhotoData != nil {
                                Button("Remover foto", role: .destructive) { draft.coverPhotoData = nil }
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .listRowBackground(Palette.surface)
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                        .listRowBackground(Palette.surface)
                }
            }
            .canvasBackground()
            .tint(Palette.accentText)
            .navigationTitle(isEditing ? "Editar meta" : "Nova meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(!draft.isValid)
                        .accessibilityIdentifier("goalEditor.save")
                }
            }
            .interactiveDismissDisabled(finalDraft != initialDraft)
        }
    }

    private func addStep() {
        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        draft.steps.append(.init(title: title))
        newStep = ""
    }

    private func save() {
        do {
            switch mode {
            case .create:
                try environment.goals.create(finalDraft, in: space, by: userRecordName)
            case .edit(let goal):
                try environment.goals.update(goal, with: finalDraft, by: userRecordName)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    NavigationStack {
        GoalsView(environment: environment, space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID)
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
