//
//  DailyQuestionViews.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Where the current user stands on one day's question. Built only from stored records:
/// "Seu par já respondeu" appears only when the partner's answer is on this device.
enum DailyStatus: Equatable {
    /// No question for this day on this device yet (not prepared, or not synced).
    case unavailable
    case notAnswered(hasDraft: Bool, partnerAnswered: Bool)
    /// Sent; the partner has not answered (or has not joined).
    case waiting
    case revealed

    static func of(_ state: DailyState?, draft: String) -> DailyStatus {
        guard let state else { return .unavailable }
        if state.isRevealed { return .revealed }
        if state.mine != nil { return .waiting }
        return .notAnswered(hasDraft: !draft.trimmed.isEmpty, partnerAnswered: state.partner != nil)
    }
}

// MARK: - Início card

/// "Hoje, nós dois" on Início: today's question, its real state and the way in.
struct MomentsHomeCard: View {
    let context: MomentsContext

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            card
        }
    }

    private var todayKey: String? { context.repository.todayKey(in: context.space) }
    private var session: DailyQuestion? { todayKey.flatMap { context.repository.session(for: $0, in: context.space) } }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Hoje, nós dois")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.xs)
                if let category = session?.category.flatMap(QuestionCategory.init(rawValue:)) {
                    TagChip(title: category.title, systemImage: category.systemImage)
                }
            }
            if case .failure = context.environment.catalog {
                Text("O conteúdo desta área não pôde ser carregado. Atualize o app.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            } else if let session, let dayKey = session.dayKey {
                let status = DailyStatus.of(context.repository.state(of: session, for: context.userRecordName), draft: context.local.answerDraft(for: dayKey))
                Text(session.questionText ?? "")
                    .font(.noteQuote)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(statusText(status), systemImage: statusImage(status))
                    .font(.subheadline)
                    .foregroundStyle(status == .revealed ? Palette.success : Palette.textSecondary)
                NavigationLink(value: MomentsRoute.daily(dayKey: dayKey)) {
                    Text(actionTitle(status))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("moments.home.action")
            } else {
                Text(context.isOwner
                     ? "Preparando a pergunta de hoje…"
                     : "A pergunta de hoje ainda não chegou a este iPhone. Ela aparece depois que o iCloud sincronizar.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            NavigationLink(value: MomentsRoute.explore) {
                Text("Explorar momentos")
            }
            .buttonStyle(.text)
            .accessibilityIdentifier("moments.home.explore")
        }
        .surfaceCard()
    }

    private func statusText(_ status: DailyStatus) -> String {
        switch status {
        case .unavailable: ""
        case .notAnswered(_, true): String(localized: "\(context.partnerName) já respondeu.")
        case .notAnswered(true, false): String(localized: "Você tem um rascunho guardado neste iPhone.")
        case .notAnswered(false, false): String(localized: "Uma pergunta para se descobrirem.")
        case .waiting:
            context.partner == nil
                ? String(localized: "Resposta enviada. Seu par ainda não está no espaço.")
                : String(localized: "Resposta enviada. Esperando \(context.partnerName).")
        case .revealed: String(localized: "Vocês dois responderam.")
        }
    }

    private func statusImage(_ status: DailyStatus) -> String {
        switch status {
        case .unavailable: "clock"
        case .notAnswered(_, true): "person.fill.checkmark"
        case .notAnswered: "bubble.left"
        case .waiting: "hourglass"
        case .revealed: "heart.circle.fill"
        }
    }

    private func actionTitle(_ status: DailyStatus) -> LocalizedStringKey {
        switch status {
        case .notAnswered(true, _): "Continuar"
        case .notAnswered: "Responder"
        case .waiting, .unavailable: "Ver pergunta"
        case .revealed: "Ver respostas"
        }
    }
}

// MARK: - Question of a day

/// One day's question: editor with local draft, sending, waiting, then "Nossa descoberta".
struct DailyQuestionView: View {
    let context: MomentsContext
    let dayKey: String

    @State private var text = ""
    @State private var didLoadDraft = false
    @State private var isConfirmingSend = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var memoryEditor: DailyQuestion?
    @FocusState private var isEditing: Bool

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Pergunta do dia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: MomentsRoute.history) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel(Text("Perguntas anteriores"))
            }
        }
        .onAppear {
            guard !didLoadDraft else { return }
            didLoadDraft = true
            text = context.local.answerDraft(for: dayKey)
        }
        .onChange(of: text) {
            // Kept only on this iPhone until it is sent.
            context.local.setAnswerDraft(text, for: dayKey)
        }
        .sheet(item: $memoryEditor) { session in
            MemoryEditorView(
                environment: context.environment,
                mode: .create(context.space),
                userRecordName: context.userRecordName,
                prefill: memoryDraft(for: session),
                onSaved: { memory in try? context.repository.linkMemory(memory.id, to: session) }
            )
        }
    }

    private var session: DailyQuestion? { context.repository.session(for: dayKey, in: context.space) }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let session, let state = context.repository.state(of: session, for: context.userRecordName) {
                    questionHeader(session)
                    if state.isRevealed, let mine = state.mine, let partner = state.partner {
                        DiscoverySection(context: context, session: session, mine: mine, partner: partner) {
                            memoryEditor = session
                        }
                    } else if let mine = state.mine {
                        sentSection(mine: mine)
                    } else {
                        editor(session: session, partnerAnswered: state.partner != nil)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "clock",
                        title: "Pergunta ainda não disponível",
                        message: "A pergunta deste dia ainda não chegou a este iPhone. Ela aparece depois que o iCloud sincronizar; não criamos outra pergunta só para você."
                    )
                    .padding(.top, Spacing.xxl)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .padding(Spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func questionHeader(_ session: DailyQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                if let category = session.category.flatMap(QuestionCategory.init(rawValue:)) {
                    TagChip(title: category.title, systemImage: category.systemImage)
                }
                Text(MomentsDayText.text(for: dayKey, todayKey: context.repository.todayKey(in: context.space), timeZone: context.repository.timeZone(of: context.space)))
                    .font(.metadata)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(session.questionText ?? "")
                .font(.displayTitle)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func editor(session: DailyQuestion, partnerAnswered: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if partnerAnswered {
                Label("\(context.partnerName) já respondeu. A resposta aparece depois que você enviar a sua.", systemImage: "person.fill.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            TextField("Sua resposta", text: $text, axis: .vertical)
                .lineLimit(4...12)
                .focused($isEditing)
                .padding(Spacing.m)
                .background(Palette.surface, in: .rect(cornerRadius: Radius.button, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Palette.hairline)
                }
                .accessibilityIdentifier("daily.answer")
            HStack {
                Text(text.trimmed.isEmpty ? "" : String(localized: "Rascunho guardado só neste iPhone."))
                Spacer()
                Text("\(text.trimmed.count)/\(MomentsRepository.maximumAnswerLength)")
                    .monospacedDigit()
            }
            .font(.metadata)
            .foregroundStyle(text.trimmed.count > MomentsRepository.maximumAnswerLength ? Palette.accentText : Palette.textSecondary)
            Button {
                isEditing = false
                isConfirmingSend = true
            } label: {
                Text("Enviar resposta")
            }
            .buttonStyle(.primary)
            .disabled(text.trimmed.isEmpty || text.trimmed.count > MomentsRepository.maximumAnswerLength || isSending)
            .accessibilityIdentifier("daily.send")
            .confirmationDialog("Enviar resposta?", isPresented: $isConfirmingSend, titleVisibility: .visible) {
                Button("Enviar") { send(to: session) }
                Button("Continuar editando", role: .cancel) {}
            } message: {
                Text("Depois de enviada, a resposta não muda. As respostas aparecem quando vocês dois tiverem respondido.")
            }
        }
    }

    private func sentSection(mine: DailyAnswer) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            AnswerCard(title: String(localized: "Sua resposta"), text: mine.text ?? "", reaction: nil, date: mine.submittedAt)
            InfoCard(
                systemImage: "hourglass",
                title: context.partner == nil ? "Seu par ainda não está no espaço" : "Esperando \(context.partnerName)",
                message: context.environment.network.isConnected
                    ? "Quando vocês dois tiverem respondido, as respostas aparecem aqui."
                    : "Sem conexão: sua resposta está salva neste iPhone e será enviada quando a internet voltar."
            )
        }
    }

    private func send(to session: DailyQuestion) {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            try context.repository.submitAnswer(text, to: session, by: context.userRecordName)
            context.local.setAnswerDraft("", for: dayKey)
            text = ""
            errorMessage = nil
            context.environment.momentsDidChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func memoryDraft(for session: DailyQuestion) -> MemoryDraft {
        var draft = MemoryDraft()
        draft.title = String((session.questionText ?? String(localized: "Nossa descoberta")).prefix(80))
        if let state = context.repository.state(of: session, for: context.userRecordName) {
            let lines = [state.mine, state.partner].compactMap { answer in
                answer.map { String(localized: "\(context.name(for: $0.authorID)): \($0.text ?? "")") }
            }
            draft.details = lines.joined(separator: "\n\n")
        }
        if let zone = context.repository.timeZone(of: context.space), let date = MomentsCalendar.date(forDayKey: dayKey, in: zone) {
            draft.date = min(date, .now)
        }
        draft.category = .special
        return draft
    }
}

/// "Nossa descoberta": both answers, each person's reaction and saving as a memory.
struct DiscoverySection: View {
    let context: MomentsContext
    let session: DailyQuestion
    let mine: DailyAnswer
    let partner: DailyAnswer
    let saveMemory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(title: "Nossa descoberta")
            AnswerCard(
                title: String(localized: "Você"),
                text: mine.text ?? "",
                reaction: partner.reaction.flatMap(MomentReaction.init(rawValue:)).map { (context.partnerName, $0) },
                date: mine.submittedAt
            )
            AnswerCard(
                title: context.name(for: partner.authorID),
                text: partner.text ?? "",
                reaction: mine.reaction.flatMap(MomentReaction.init(rawValue:)).map { (String(localized: "Você"), $0) },
                date: partner.submittedAt
            )
            reactionPicker
            if let memoryID = session.memoryID {
                NavigationLink(value: MomentsRoute.memory(memoryID)) {
                    Label("Ver memória", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.soft)
            } else {
                Button(action: saveMemory) {
                    Label("Guardar como memória", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.soft)
                .accessibilityIdentifier("daily.saveMemory")
            }
        }
    }

    private var reactionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Sua reação à resposta de \(context.name(for: partner.authorID))")
                .font(.metadata)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: Spacing.xs) {
                ForEach(MomentReaction.allCases) { reaction in
                    let isSelected = mine.reaction == reaction.rawValue
                    Button {
                        try? context.repository.setReaction(isSelected ? nil : reaction.rawValue, on: mine, by: context.userRecordName)
                    } label: {
                        Image(systemName: reaction.systemImage)
                            .font(.title3)
                            .frame(width: 48, height: 44)
                            .foregroundStyle(isSelected ? Palette.onAccent : Palette.accentText)
                            .background(isSelected ? Palette.accent : Palette.surfaceMuted, in: .capsule)
                    }
                    .buttonStyle(.tile)
                    .accessibilityLabel(Text(reaction.title))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

/// One answer: who, what, when and the other person's reaction.
struct AnswerCard: View {
    let title: String
    let text: String
    let reaction: (by: String, reaction: MomentReaction)?
    let date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text(text)
                .font(.noteQuote)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.xs) {
                if let date {
                    Text(NoteTimestamp.text(for: date))
                }
                if let reaction {
                    Spacer(minLength: Spacing.xs)
                    Label(String(localized: "\(reaction.by): \(reaction.reaction.title)"), systemImage: reaction.reaction.systemImage)
                        .foregroundStyle(Palette.accentText)
                }
            }
            .font(.metadata)
            .foregroundStyle(Palette.textSecondary)
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - History

/// Earlier questions, newest first. An unanswered day can still be answered here.
struct DailyHistoryView: View {
    let context: MomentsContext

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            list
        }
        .canvasBackground()
        .navigationTitle("Perguntas anteriores")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var list: some View {
        let todayKey = context.repository.todayKey(in: context.space)
        let sessions = todayKey.map { context.repository.history(in: context.space, untilDayKey: $0) } ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s) {
                if sessions.isEmpty {
                    EmptyStateView(systemImage: "clock.arrow.circlepath", title: "Nenhuma pergunta ainda", message: "As perguntas de cada dia ficam guardadas aqui.")
                        .padding(.top, Spacing.xxl)
                }
                ForEach(sessions) { session in
                    if let dayKey = session.dayKey {
                        NavigationLink(value: MomentsRoute.daily(dayKey: dayKey)) {
                            row(session, dayKey: dayKey, todayKey: todayKey)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.screen)
        }
    }

    private func row(_ session: DailyQuestion, dayKey: String, todayKey: String?) -> some View {
        let state = context.repository.state(of: session, for: context.userRecordName)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(MomentsDayText.text(for: dayKey, todayKey: todayKey, timeZone: context.repository.timeZone(of: context.space)))
                .font(.metadata)
                .foregroundStyle(Palette.textSecondary)
            Text(session.questionText ?? "")
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)
            participation(state)
        }
        .surfaceCard()
    }

    @ViewBuilder
    private func participation(_ state: DailyState?) -> some View {
        if state?.isRevealed == true {
            StatusChip(title: "Vocês dois responderam", systemImage: "heart.circle.fill", tone: .success)
        } else if state?.mine != nil {
            StatusChip(title: "Você respondeu", systemImage: "checkmark", tone: .neutral)
        } else if state?.partner != nil {
            StatusChip(title: "Seu par respondeu", systemImage: "person.fill.checkmark")
        } else {
            StatusChip(title: "Sem respostas", systemImage: "bubble.left", tone: .neutral)
        }
    }
}
