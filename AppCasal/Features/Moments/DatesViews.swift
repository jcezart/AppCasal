//
//  DatesViews.swift
//  AppCasal
//

import CoreData
import SwiftUI

// MARK: - Escolhe por nós

/// Draws a date idea from the catalog, the couple's "Queremos ir" places and their own
/// ideas, with independent filters. A discreet draw: no wheel, no effects.
struct DatesView: View {
    let context: MomentsContext

    @State private var filters = DateFilters()
    @State private var current: DateCandidate?
    @State private var shown: Set<String> = []
    @State private var confirmation: String?
    @State private var errorMessage: String?
    @State private var generator = SystemRandomNumberGenerator()
    @State private var didSetSources = false

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Escolhe por nós")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: MomentsRoute.ideas) {
                    Image(systemName: "lightbulb")
                }
                .accessibilityLabel(Text("Nossas ideias"))
            }
        }
        .onChange(of: filters) {
            current = nil
            shown = []
            confirmation = nil
        }
        .onAppear {
            // Offer the couple's own sources when they have something in them.
            guard !didSetSources else { return }
            didSetSources = true
            if !wishlistPlaces.isEmpty { filters.sources.insert(.place) }
            if !context.repository.ideas(in: context.space).isEmpty { filters.sources.insert(.idea) }
        }
    }

    private var candidates: [DateCandidate] {
        var all: [DateCandidate] = []
        if case .success(let catalog) = context.environment.catalog {
            all += catalog.dates.map(DateCandidate.init)
        }
        all += wishlistPlaces.compactMap { place in
            place.id.map { DateCandidate(placeID: $0, name: place.name ?? "", note: place.note) }
        }
        all += context.repository.ideas(in: context.space).compactMap(MomentsRepository.candidate(from:))
        return all
    }

    private var wishlistPlaces: [Place] {
        (context.space.places ?? []).filter { $0.deletedAt == nil && $0.status == PlaceStatus.wishlist.rawValue }
    }

    private var eligible: [DateCandidate] { DateDraw.eligible(candidates, filters: filters) }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                MomentsHeader(systemImage: "dice", title: "Uma ideia para vocês", message: "Escolham de onde vêm as ideias e o que cabe no dia. Custos e durações são estimativas.")
                sourcesCard
                filtersCard
                if let current {
                    DateCandidateCard(candidate: current)
                    actions(for: current)
                } else {
                    drawArea
                }
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Palette.success)
                    NavigationLink(value: MomentsRoute.plans) {
                        Text("Ver planos e convites")
                    }
                    .buttonStyle(.text)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .padding(Spacing.screen)
        }
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionLabel(title: "De onde vêm as ideias")
            ForEach(DateCandidate.Kind.allCases, id: \.self) { kind in
                Toggle(isOn: sourceBinding(kind)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                        Text(sourceDetail(kind))
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .tint(Palette.accent)
            }
        }
        .surfaceCard()
    }

    private func sourceDetail(_ kind: DateCandidate.Kind) -> String {
        switch kind {
        case .catalog: String(localized: "100 ideias para casais.")
        case .place: String(localized: "\(wishlistPlaces.count) lugar(es) salvos no Mapa.")
        case .idea: String(localized: "\(context.repository.ideas(in: context.space).count) ideia(s) de vocês.")
        }
    }

    private func sourceBinding(_ kind: DateCandidate.Kind) -> Binding<Bool> {
        Binding {
            filters.sources.contains(kind)
        } set: { isOn in
            if isOn {
                filters.sources.insert(kind)
            } else if filters.sources.count > 1 {
                filters.sources.remove(kind)
            }
        }
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionLabel(title: "Filtros")
            Picker("Lugar", selection: $filters.location) {
                ForEach(LocationFilter.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Custo", selection: $filters.cost) {
                ForEach(CostFilter.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Duração", selection: $filters.duration) {
                ForEach(DurationFilter.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }
        .pickerStyle(.menu)
        .tint(Palette.accentText)
        .surfaceCard()
    }

    @ViewBuilder
    private var drawArea: some View {
        let eligible = eligible
        if eligible.isEmpty {
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "Nenhuma ideia com esses filtros",
                message: "Os filtros continuam valendo: nenhuma ideia cabe em todos eles ao mesmo tempo.",
                actionTitle: "Limpar filtros",
                action: { filters = DateFilters(sources: filters.sources) }
            )
        } else if eligible.allSatisfy({ shown.contains($0.id) }) {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "Vocês já viram todas",
                message: "Já apareceram as \(eligible.count) ideias com esses filtros.",
                actionTitle: "Começar de novo",
                action: { shown = []; draw() }
            )
        } else {
            Button(action: draw) {
                Label("Sortear uma ideia", systemImage: "dice")
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("dates.draw")
            Text("\(eligible.count) ideia(s) com esses filtros.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func actions(for candidate: DateCandidate) -> some View {
        VStack(spacing: Spacing.xs) {
            Button {
                plan(candidate, invite: false)
            } label: {
                Text("Vamos fazer")
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("dates.plan")
            Button {
                plan(candidate, invite: true)
            } label: {
                Label("Convidar meu par", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.soft)
            .disabled(context.partner == nil)
            Button("Outra ideia", action: draw)
                .buttonStyle(.text)
                .accessibilityIdentifier("dates.another")
        }
    }

    private func draw() {
        confirmation = nil
        guard let next = DateDraw.next(from: eligible, excluding: shown, using: &generator) else {
            current = nil
            return
        }
        shown.insert(next.id)
        current = next
    }

    private func plan(_ candidate: DateCandidate, invite: Bool) {
        do {
            try context.repository.plan(candidate, invite: invite, in: context.space, by: context.userRecordName)
            confirmation = invite
                ? String(localized: "Convite enviado para \(context.partnerName). Aparece quando o iCloud sincronizar.")
                : String(localized: "Combinado! O plano está em Planos e convites.")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A drawn idea: what, where, how much (as guidance), how long and what to bring.
struct DateCandidateCard: View {
    let candidate: DateCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TagChip(title: candidate.kind.title)
            Text(candidate.title)
                .font(.cardTitle)
                .foregroundStyle(Palette.textPrimary)
            if let details = candidate.details {
                Text(details)
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Label(candidate.location?.title ?? String(localized: "Lugar a confirmar"), systemImage: "mappin")
                Label(candidate.cost.title, systemImage: "creditcard")
                Label(durationText, systemImage: "clock")
                if candidate.remoteFriendly {
                    Label("Dá para fazer à distância", systemImage: "video")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textSecondary)
            if !candidate.materials.isEmpty {
                Text("Vocês vão precisar: \(candidate.materials.joined(separator: ", ")).")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            if let note = candidate.costNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }

    private var durationText: String {
        guard let minutes = candidate.durationMinutes else { return String(localized: "Duração a confirmar") }
        let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return String(localized: "Cerca de \(duration)")
    }
}

// MARK: - Planos e convites

/// Plans and invitations, answered in place. Marking as done never creates a memory or
/// changes a place by itself; "Guardar esse momento" opens the memory editor.
struct DatePlansView: View {
    let context: MomentsContext

    @State private var memoryFor: DatePlan?
    @State private var errorMessage: String?

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Planos e convites")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $memoryFor) { plan in
            memoryEditor(for: plan)
        }
    }

    private var plans: [DatePlan] { context.repository.plans(in: context.space) }

    private var content: some View {
        let me = context.userRecordName
        let invitedMe = plans.filter { $0.completedAt == nil && $0.invitation == DateInvitation.pending.rawValue && $0.createdBy != me }
        let myInvites = plans.filter { $0.completedAt == nil && $0.invitation == DateInvitation.pending.rawValue && $0.createdBy == me }
        let agreed = plans.filter { $0.completedAt == nil && ($0.invitation == nil || $0.invitation == DateInvitation.accepted.rawValue) }
        let closed = plans.filter { $0.completedAt == nil && ($0.invitation == DateInvitation.declined.rawValue || $0.invitation == DateInvitation.cancelled.rawValue) }
        let done = plans.filter { $0.completedAt != nil }
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if plans.isEmpty {
                    EmptyStateView(systemImage: "calendar", title: "Nada combinado ainda", message: "Em Escolhe por nós, toquem em Vamos fazer ou convidem o seu par.")
                        .padding(.top, Spacing.xxl)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                section("Convites para você", invitedMe) { plan in
                    AdaptiveStack(spacing: Spacing.xs) {
                        Button("Aceitar") { act { try context.repository.respond(to: plan, accept: true, by: me) } }
                            .buttonStyle(.soft)
                        Button("Agora não") { act { try context.repository.respond(to: plan, accept: false, by: me) } }
                            .buttonStyle(.text)
                    }
                }
                section("Seus convites", myInvites) { plan in
                    Button("Cancelar convite") { act { try context.repository.cancelInvitation(plan, by: me) } }
                        .buttonStyle(.text)
                }
                section("Combinados", agreed) { plan in
                    Button {
                        act { try context.repository.complete(plan, by: me) }
                    } label: {
                        Label("Marcar como feito", systemImage: "checkmark")
                    }
                    .buttonStyle(.soft)
                }
                section("Feitos", done) { plan in
                    if let memoryID = plan.memoryID {
                        NavigationLink(value: MomentsRoute.memory(memoryID)) {
                            Label("Ver memória", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.soft)
                    } else {
                        Button {
                            memoryFor = plan
                        } label: {
                            Label(isPlace(plan) ? "Registrar visita e guardar" : "Guardar esse momento", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.soft)
                    }
                }
                section("Recusados ou cancelados", closed) { _ in EmptyView() }
            }
            .padding(Spacing.screen)
        }
    }

    @ViewBuilder
    private func section<Actions: View>(_ title: LocalizedStringKey, _ items: [DatePlan], @ViewBuilder actions: @escaping (DatePlan) -> Actions) -> some View {
        if !items.isEmpty {
            SectionLabel(title: title)
            ForEach(items) { plan in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(plan.title ?? "")
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                    if let details = plan.details {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Text(caption(for: plan))
                        .font(.metadata)
                        .foregroundStyle(Palette.textSecondary)
                    actions(plan)
                }
                .surfaceCard()
                .contextMenu {
                    Button("Remover", systemImage: "trash", role: .destructive) {
                        act { try context.repository.softDelete(plan, by: context.userRecordName) }
                    }
                }
            }
        }
    }

    private func caption(for plan: DatePlan) -> String {
        let who = context.name(for: plan.createdBy)
        switch plan.invitation.flatMap(DateInvitation.init(rawValue:)) {
        case .pending: return String(localized: "Convite de \(who)")
        case .accepted: return String(localized: "Convite aceito")
        case .declined: return String(localized: "Convite recusado")
        case .cancelled: return String(localized: "Convite cancelado")
        case nil:
            if let completed = plan.completedAt { return String(localized: "Feito \(NoteTimestamp.text(for: completed))") }
            return String(localized: "Combinado por \(who)")
        }
    }

    private func isPlace(_ plan: DatePlan) -> Bool {
        plan.sourceKind == DateCandidate.Kind.place.rawValue && place(for: plan) != nil
    }

    private func place(for plan: DatePlan) -> Place? {
        guard plan.sourceKind == DateCandidate.Kind.place.rawValue, let id = plan.sourceID.flatMap(UUID.init(uuidString:)) else { return nil }
        return context.environment.places.place(withID: id, in: context.space)
    }

    private func memoryEditor(for plan: DatePlan) -> some View {
        var draft = MemoryDraft()
        draft.title = String((plan.title ?? "").prefix(80))
        draft.details = plan.details ?? ""
        draft.date = min(plan.completedAt ?? .now, .now)
        draft.category = .date
        // A saved place goes through the existing "registrar visita" flow, on save only.
        return MemoryEditorView(
            environment: context.environment,
            mode: .create(context.space),
            userRecordName: context.userRecordName,
            visit: place(for: plan),
            prefill: draft,
            onSaved: { memory in try? context.repository.linkMemory(memory.id, to: plan) }
        )
    }

    private func act(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Nossas ideias

/// The couple's own ideas: both see them; only the author edits or deletes.
struct DateIdeasView: View {
    let context: MomentsContext

    @State private var editing: IdeaEditorMode?
    @State private var errorMessage: String?

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            list
        }
        .canvasBackground()
        .navigationTitle("Nossas ideias")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nova ideia", systemImage: "plus") { editing = .new }
                    .accessibilityIdentifier("ideas.add")
            }
        }
        .sheet(item: $editing) { mode in
            DateIdeaEditorView(context: context, mode: mode)
        }
    }

    private var list: some View {
        let ideas = context.repository.ideas(in: context.space)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s) {
                if ideas.isEmpty {
                    EmptyStateView(
                        systemImage: "lightbulb",
                        title: "Nenhuma ideia de vocês ainda",
                        message: "Guardem aqui encontros que vocês querem viver. Eles entram no sorteio quando Nossas ideias estiver ligado.",
                        actionTitle: "Nova ideia",
                        action: { editing = .new }
                    )
                    .padding(.top, Spacing.xxl)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                ForEach(ideas) { idea in
                    if let candidate = MomentsRepository.candidate(from: idea) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            DateCandidateCard(candidate: candidate)
                            Text("Ideia de \(context.name(for: idea.authorID))")
                                .font(.metadata)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .contextMenu {
                            if idea.authorID == context.userRecordName {
                                Button("Editar", systemImage: "pencil") { editing = .edit(idea) }
                                Button("Excluir", systemImage: "trash", role: .destructive) {
                                    do {
                                        try context.repository.softDeleteIdea(idea, by: context.userRecordName)
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.screen)
        }
    }
}

enum IdeaEditorMode: Identifiable {
    case new
    case edit(DateIdea)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let idea): idea.objectID.uriRepresentation().absoluteString
        }
    }
}

struct DateIdeaEditorView: View {
    let context: MomentsContext
    let mode: IdeaEditorMode

    @Environment(\.dismiss) private var dismiss
    @State private var draft: DateIdeaDraft
    @State private var hasDuration: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(context: MomentsContext, mode: IdeaEditorMode) {
        self.context = context
        self.mode = mode
        let draft: DateIdeaDraft
        if case .edit(let idea) = mode {
            draft = MomentsRepository.draft(from: idea)
        } else {
            draft = DateIdeaDraft()
        }
        _draft = State(initialValue: draft)
        _hasDuration = State(initialValue: draft.durationMinutes != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $draft.title)
                        .accessibilityIdentifier("ideaEditor.title")
                    TextField("Como seria", text: $draft.details, axis: .vertical)
                        .lineLimit(3...8)
                } footer: {
                    Text("Até \(DateIdeaDraft.titleLimit) caracteres no título e \(DateIdeaDraft.detailsLimit) na descrição.")
                }
                .listRowBackground(Palette.surface)
                Section {
                    Picker("Lugar", selection: $draft.location) {
                        ForEach(DateLocation.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Custo estimado", selection: $draft.cost) {
                        ForEach(DateCost.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Toggle("Informar duração", isOn: $hasDuration)
                        .tint(Palette.accent)
                    if hasDuration {
                        Stepper(value: durationBinding, in: DateIdeaDraft.durationRange, step: 15) {
                            Text("Cerca de \(durationBinding.wrappedValue) min")
                        }
                    }
                    Toggle("Dá para fazer à distância", isOn: $draft.remoteFriendly)
                        .tint(Palette.accent)
                        .disabled(draft.location == .fora)
                } footer: {
                    Text("Custo e duração são só uma orientação para vocês.")
                }
                .listRowBackground(Palette.surface)
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                        .listRowBackground(Palette.surface)
                }
            }
            .canvasBackground()
            .tint(Palette.accentText)
            .navigationTitle(isEditing ? "Editar ideia" : "Nova ideia")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: hasDuration) { draft.durationMinutes = hasDuration ? (draft.durationMinutes ?? 60) : nil }
            .onChange(of: draft.location) { if draft.location == .fora { draft.remoteFriendly = false } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", systemImage: "checkmark", role: .confirm, action: save)
                        .confirmationButtonStyle()
                        .disabled(!draft.isValid || isSaving)
                        .accessibilityIdentifier("ideaEditor.save")
                }
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var durationBinding: Binding<Int> {
        Binding { draft.durationMinutes ?? 60 } set: { draft.durationMinutes = $0 }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        do {
            switch mode {
            case .new:
                try context.repository.createIdea(draft, in: context.space, by: context.userRecordName)
            case .edit(let idea):
                try context.repository.updateIdea(idea, with: draft, by: context.userRecordName)
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}
