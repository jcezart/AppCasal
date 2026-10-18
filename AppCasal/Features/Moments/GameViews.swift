//
//  GameViews.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// "Quem conhece melhor?": five questions; each person answers about themselves and
/// guesses the partner. Answers show only after both finish. A light result, never a
/// compatibility score, ranking or streak.
struct GameView: View {
    let context: MomentsContext

    @State private var entries: [GameEntry] = []
    @State private var index = 0
    @State private var loadedRoundID: UUID?
    @State private var isConfirmingSend = false
    @State private var isConfirmingCancel = false
    @State private var errorMessage: String?
    @State private var generator = SystemRandomNumberGenerator()

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Quem conhece melhor?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var openRound: GameRound? { context.repository.openRound(in: context.space) }

    private var lastFinished: GameRound? {
        context.repository.rounds(in: context.space).first { context.repository.isFinished($0) }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let round = openRound {
                    if context.repository.gameAnswer(for: round, by: context.userRecordName) != nil {
                        waiting(round)
                    } else {
                        play(round)
                    }
                } else {
                    MomentsHeader(systemImage: "person.2.wave.2", title: "Quem conhece melhor?", message: "Cada um escolhe uma resposta sobre si e tenta adivinhar a do par. Não existe resposta certa: vale a escolha de cada um.")
                    if let round = lastFinished {
                        GameResultsView(context: context, round: round)
                    }
                    Button(lastFinished == nil ? "Começar rodada" : "Nova rodada", action: start)
                        .buttonStyle(.primary)
                        .disabled(context.partner == nil)
                        .accessibilityIdentifier("game.start")
                    if context.partner == nil {
                        Text("A rodada é para dois: convide seu par primeiro.")
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .padding(Spacing.screen)
        }
    }

    // MARK: Playing

    @ViewBuilder
    private func play(_ round: GameRound) -> some View {
        let questions = context.repository.snapshots(of: round)
        if !questions.isEmpty {
            let current = min(index, questions.count - 1)
            let question = questions[current]
            VStack(alignment: .leading, spacing: Spacing.m) {
                if round.createdBy != context.userRecordName {
                    Label("\(context.partnerName) começou esta rodada.", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Text("Pergunta \(current + 1) de \(questions.count)")
                    .font(.metadata)
                    .foregroundStyle(Palette.textSecondary)
                ProgressBar(value: Double(current + 1) / Double(questions.count))
                Text(question.text)
                    .font(.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                optionGroup(title: "Sobre você", question: question, selected: entry(for: question.id).selfOptionID) { option in
                    update(question.id, round: round) { $0.selfOptionID = option }
                }
                optionGroup(title: "Seu palpite sobre \(context.partnerName)", question: question, selected: entry(for: question.id).guessOptionID) { option in
                    update(question.id, round: round) { $0.guessOptionID = option }
                }
                Button("Pular esta pergunta") {
                    update(question.id, round: round) { $0.selfOptionID = nil; $0.guessOptionID = nil }
                    if current < questions.count - 1 { index = current + 1 }
                }
                .buttonStyle(.text)
                AdaptiveStack(spacing: Spacing.s) {
                    if current > 0 {
                        Button("Voltar") { index = current - 1 }
                            .buttonStyle(.soft)
                    }
                    if current < questions.count - 1 {
                        Button("Próxima") { index = current + 1 }
                            .buttonStyle(.primary)
                            .accessibilityIdentifier("game.next")
                    } else {
                        Button("Enviar respostas") { isConfirmingSend = true }
                            .buttonStyle(.primary)
                            .accessibilityIdentifier("game.send")
                    }
                }
                Text("Suas escolhas ficam guardadas só neste iPhone até você enviar.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .onAppear { loadDraft(round, questions: questions) }
            .confirmationDialog("Enviar respostas?", isPresented: $isConfirmingSend, titleVisibility: .visible) {
                Button("Enviar") { send(round, questions: questions) }
                Button("Continuar jogando", role: .cancel) {}
            } message: {
                Text("Depois de enviadas, as respostas não mudam. O resultado aparece quando vocês dois terminarem.")
            }
        }
    }

    private func optionGroup(title: LocalizedStringKey, question: GameQuestionSnapshot, selected: String?, choose: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionLabel(title: title)
            ForEach(question.options) { option in
                let isSelected = option.id == selected
                Button { choose(option.id) } label: {
                    HStack {
                        Text(option.text)
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Spacing.xs)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Palette.accent : Palette.textSecondary)
                    }
                    .padding(Spacing.s)
                    .frame(minHeight: 44)
                    .background(isSelected ? Palette.surfaceMuted : Palette.surface, in: .rect(cornerRadius: Radius.button, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .strokeBorder(isSelected ? Palette.accent : Palette.hairline)
                    }
                }
                .buttonStyle(.tile)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func entry(for questionID: String) -> GameEntry {
        entries.first { $0.questionID == questionID } ?? GameEntry(questionID: questionID)
    }

    private func update(_ questionID: String, round: GameRound, _ change: (inout GameEntry) -> Void) {
        var entry = entry(for: questionID)
        change(&entry)
        entries.removeAll { $0.questionID == questionID }
        entries.append(entry)
        if let id = round.id {
            context.local.setGameDraft(entries, for: id)
        }
    }

    private func loadDraft(_ round: GameRound, questions: [GameQuestionSnapshot]) {
        guard let id = round.id, loadedRoundID != id else { return }
        loadedRoundID = id
        entries = context.local.gameDraft(for: id)
        // Resume at the first question without any choice.
        index = questions.firstIndex { question in !entries.contains { $0.questionID == question.id } } ?? 0
    }

    private func send(_ round: GameRound, questions: [GameQuestionSnapshot]) {
        let complete = questions.map { entry(for: $0.id) }
        do {
            try context.repository.submitGame(complete, for: round, by: context.userRecordName)
            if let id = round.id { context.local.setGameDraft(nil, for: id) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func start() {
        guard case .success(let catalog) = context.environment.catalog else { return }
        do {
            try context.repository.startRound(in: context.space, questions: catalog.gameQuestions, catalogVersion: catalog.gameVersion, by: context.userRecordName, using: &generator)
            index = 0
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Waiting

    private func waiting(_ round: GameRound) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            MomentsHeader(systemImage: "hourglass", title: "Você terminou", message: "Esperando \(context.partnerName) terminar. O resultado aparece para os dois ao mesmo tempo.")
            if round.createdBy == context.userRecordName {
                Button("Cancelar rodada") { isConfirmingCancel = true }
                    .buttonStyle(.text)
                    .confirmationDialog("Cancelar esta rodada?", isPresented: $isConfirmingCancel, titleVisibility: .visible) {
                        Button("Cancelar rodada", role: .destructive) {
                            do {
                                try context.repository.cancelRound(round, by: context.userRecordName)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        Button("Manter", role: .cancel) {}
                    }
            }
        }
    }
}

/// Results of a finished round, question by question, compared by option ID.
struct GameResultsView: View {
    let context: MomentsContext
    let round: GameRound

    var body: some View {
        let questions = context.repository.snapshots(of: round)
        let mine = context.repository.entries(of: context.repository.gameAnswer(for: round, by: context.userRecordName))
        let partnerID = context.partner?.userRecordName ?? ""
        let theirs = context.repository.entries(of: context.repository.gameAnswer(for: round, by: partnerID))
        let myScore = GameRules.score(guesser: mine, chooser: theirs)
        let theirScore = GameRules.score(guesser: theirs, chooser: mine)
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionLabel(title: "Última rodada")
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(summary(myScore, who: String(localized: "Você")))
                Text(summary(theirScore, who: context.partnerName))
                Text("Cada resposta mostra um pouco de quem vocês são hoje.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .font(.headline)
            .foregroundStyle(Palette.textPrimary)
            .surfaceCard()
            ForEach(questions) { question in
                let myEntry = mine.first { $0.questionID == question.id }
                let theirEntry = theirs.first { $0.questionID == question.id }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(question.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                    line(who: String(localized: "Você"), choice: question.option(withID: myEntry?.selfOptionID)?.text, guessByOther: question.option(withID: theirEntry?.guessOptionID)?.text)
                    line(who: context.partnerName, choice: question.option(withID: theirEntry?.selfOptionID)?.text, guessByOther: question.option(withID: myEntry?.guessOptionID)?.text)
                }
                .surfaceCard()
            }
        }
    }

    private func summary(_ score: GameScore, who: String) -> String {
        guard score.compared > 0 else { return String(localized: "\(who): sem palpites para comparar.") }
        return String(localized: "\(who) acertou \(score.correct) de \(score.compared).")
    }

    private func line(who: String, choice: String?, guessByOther: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "\(who) escolheu: \(choice ?? String(localized: "pulou"))"))
                .foregroundStyle(Palette.textPrimary)
            if let guessByOther {
                Text(String(localized: "Palpite recebido: \(guessByOther)"))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .font(.subheadline)
    }
}
