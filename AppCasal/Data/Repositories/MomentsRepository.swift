//
//  MomentsRepository.swift
//  AppCasal
//

import CoreData

/// Values edited in the own-idea form.
nonisolated struct DateIdeaDraft: Equatable, Sendable {
    static let titleLimit = 80
    static let detailsLimit = 500
    static let durationRange = 5...720

    var title = ""
    var details = ""
    var location = DateLocation.flexivel
    var cost = DateCost.aConfirmar
    /// Nil when not given.
    var durationMinutes: Int?
    var remoteFriendly = false

    var trimmedTitle: String { title.trimmed }
    var isValid: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= Self.titleLimit
            && details.trimmed.count <= Self.detailsLimit
            && durationMinutes.map(Self.durationRange.contains) ?? true
            && !(remoteFriendly && location == .fora)
    }
}

/// The daily question of one day with both answers, from the current user's side.
nonisolated struct DailyState {
    let session: DailyQuestion
    let mine: DailyAnswer?
    let partner: DailyAnswer?

    /// Both partners sent an answer to this day's question. Only then the answers show.
    /// This is a rule of the interface: the partner's answer may already be on this device.
    var isRevealed: Bool { mine != nil && partner != nil }
}

/// Writes everything of "Hoje, nós dois" in the couple space. Actions are idempotent:
/// repeating one (double tap, retry, a sync bringing the same record) returns the
/// existing record instead of creating a copy.
final class MomentsRepository {
    enum MomentsError: LocalizedError {
        case emptyAnswer
        case answerTooLong
        case alreadyAnswered
        case notAuthor
        case notOwner
        case invalidIdea
        case roundFinished

        var errorDescription: String? {
            switch self {
            case .emptyAnswer: String(localized: "Escreva sua resposta antes de enviar.")
            case .answerTooLong: String(localized: "A resposta pode ter até \(MomentsRepository.maximumAnswerLength) caracteres.")
            case .alreadyAnswered: String(localized: "Você já respondeu. A resposta enviada não muda.")
            case .notAuthor: String(localized: "Só quem escreveu pode alterar.")
            case .notOwner: String(localized: "Só quem criou o espaço prepara as perguntas.")
            case .invalidIdea: String(localized: "Confira o título, a descrição e a duração da ideia.")
            case .roundFinished: String(localized: "Esta rodada já foi concluída.")
            }
        }
    }

    nonisolated static let maximumAnswerLength = 1000

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    private func assignStore(_ object: NSManagedObject, like space: CoupleSpace) {
        if let store = space.objectID.persistentStore {
            context.assign(object, to: store)
        }
    }

    private func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        (try? context.fetch(request)) ?? []
    }

    // MARK: Daily question

    func timeZone(of space: CoupleSpace) -> TimeZone? {
        space.momentsTimeZone.flatMap(TimeZone.init(identifier:))
    }

    func todayKey(in space: CoupleSpace, now: Date = .now) -> String? {
        timeZone(of: space).map { MomentsCalendar.dayKey(for: now, in: $0) }
    }

    func allSessions(in space: CoupleSpace) -> [DailyQuestion] {
        let request = DailyQuestion.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@", space)
        return fetch(request)
    }

    /// The question of `dayKey`; with duplicates from sync, the canonical one.
    func session(for dayKey: String, in space: CoupleSpace) -> DailyQuestion? {
        let request = DailyQuestion.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND dayKey == %@", space, dayKey)
        return Canonical.pick(fetch(request), createdAt: \.createdAt, id: \.id)
    }

    /// One canonical session per day, newest first, up to `untilDayKey`.
    func history(in space: CoupleSpace, untilDayKey: String) -> [DailyQuestion] {
        let grouped = Dictionary(grouping: allSessions(in: space).filter { ($0.dayKey ?? "") <= untilDayKey }) { $0.dayKey ?? "" }
        return grouped.values
            .compactMap { Canonical.pick($0, createdAt: \.createdAt, id: \.id) }
            .sorted { ($0.dayKey ?? "") > ($1.dayKey ?? "") }
    }

    /// Owner only: gives a question to today and the next days that have none. Sets the
    /// space's time zone the first time. Running it again changes nothing already given.
    @discardableResult
    func prepareDays(
        in space: CoupleSpace,
        questions: [CatalogQuestion],
        catalogVersion: String,
        by userRecordName: String,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> Int {
        guard !persistence.isInSharedStore(space) else { throw MomentsError.notOwner }
        if space.momentsTimeZone == nil {
            space.momentsTimeZone = timeZone.identifier
            space.modifiedAt = now
        }
        let zone = self.timeZone(of: space) ?? timeZone
        let days = MomentsCalendar.dayKeys(startingAt: now, count: DailyQuestionPlanner.daysAhead, in: zone)
        let existing = allSessions(in: space).compactMap { session -> QuestionAssignment? in
            guard let day = session.dayKey, let question = session.questionID else { return nil }
            return QuestionAssignment(dayKey: day, questionID: question, cycle: Int(session.cycle))
        }
        let plan = DailyQuestionPlanner.plan(days: days, existing: existing, questions: questions)
        for item in plan {
            let session = DailyQuestion(context: context)
            assignStore(session, like: space)
            session.id = UUID()
            session.dayKey = item.dayKey
            session.questionID = item.question.id
            session.questionText = item.question.text
            session.category = item.question.category.rawValue
            session.catalogVersion = catalogVersion
            session.cycle = Int64(item.cycle)
            session.createdAt = now
            session.createdBy = userRecordName
            session.space = space
        }
        try persistence.save()
        return plan.count
    }

    func answers(for dayKey: String, in space: CoupleSpace) -> [DailyAnswer] {
        let request = DailyAnswer.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND dayKey == %@", space, dayKey)
        return fetch(request)
    }

    /// Answers count for the day's canonical question only (an answer to a duplicate
    /// session's other question stays stored, but is not mixed into this discovery).
    func state(of session: DailyQuestion, for userRecordName: String) -> DailyState? {
        guard let space = session.space, let dayKey = session.dayKey else { return nil }
        let answers = self.answers(for: dayKey, in: space).filter { $0.questionID == session.questionID && $0.submittedAt != nil }
        let mine = Canonical.pick(answers.filter { $0.authorID == userRecordName }, createdAt: \.submittedAt, id: \.id)
        let partnerID = space.members?.first { $0.userRecordName != userRecordName }?.userRecordName
        let partner = partnerID.flatMap { id in Canonical.pick(answers.filter { $0.authorID == id }, createdAt: \.submittedAt, id: \.id) }
        return DailyState(session: session, mine: mine, partner: partner)
    }

    /// Sends the current user's answer. Sent answers are final: sending again returns the
    /// existing answer when the text is the same, and refuses a different one.
    @discardableResult
    func submitAnswer(_ text: String, to session: DailyQuestion, by userRecordName: String, now: Date = .now) throws -> DailyAnswer {
        let text = text.trimmed
        guard !text.isEmpty else { throw MomentsError.emptyAnswer }
        guard text.count <= Self.maximumAnswerLength else { throw MomentsError.answerTooLong }
        guard let space = session.space else { throw MomentsError.emptyAnswer }
        if let existing = state(of: session, for: userRecordName)?.mine {
            guard existing.text == text else { throw MomentsError.alreadyAnswered }
            return existing
        }
        let answer = DailyAnswer(context: context)
        assignStore(answer, like: space)
        answer.id = UUID()
        answer.dayKey = session.dayKey
        answer.questionID = session.questionID
        answer.questionText = session.questionText
        answer.text = text
        answer.authorID = userRecordName
        answer.submittedAt = now
        answer.space = space
        try persistence.save()
        return answer
    }

    /// The author's own reaction to the discovery (nil removes it).
    func setReaction(_ reaction: String?, on answer: DailyAnswer, by userRecordName: String, now: Date = .now) throws {
        guard answer.authorID == userRecordName else { throw MomentsError.notAuthor }
        answer.reaction = reaction
        answer.reactedAt = reaction == nil ? nil : now
        try persistence.save()
    }

    /// Remembers the memory saved from this discovery; the first one stays.
    func linkMemory(_ memoryID: UUID?, to session: DailyQuestion) throws {
        guard session.memoryID == nil, let memoryID else { return }
        session.memoryID = memoryID
        try persistence.save()
    }

    // MARK: Quem conhece melhor?

    func rounds(in space: CoupleSpace) -> [GameRound] {
        let request = GameRound.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND cancelledAt == nil", space)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GameRound.createdAt, ascending: false)]
        return fetch(request)
    }

    func gameAnswers(for round: GameRound) -> [GameAnswer] {
        guard let id = round.id, let space = round.space else { return [] }
        let request = GameAnswer.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND roundID == %@", space, id as CVarArg)
        return fetch(request).filter { $0.submittedAt != nil }
    }

    func gameAnswer(for round: GameRound, by userRecordName: String) -> GameAnswer? {
        Canonical.pick(gameAnswers(for: round).filter { $0.authorID == userRecordName }, createdAt: \.submittedAt, id: \.id)
    }

    func isFinished(_ round: GameRound) -> Bool {
        guard let members = round.space?.members, members.count >= 2 else { return false }
        let authors = Set(gameAnswers(for: round).compactMap(\.authorID))
        return members.allSatisfy { member in member.userRecordName.map(authors.contains) ?? false }
    }

    /// The round in progress, if any: the earliest one not finished (deterministic when both
    /// partners started one offline).
    func openRound(in space: CoupleSpace) -> GameRound? {
        Canonical.pick(rounds(in: space).filter { !isFinished($0) }, createdAt: \.createdAt, id: \.id)
    }

    /// Starts a round, or returns the one already in progress.
    @discardableResult
    func startRound<Generator: RandomNumberGenerator>(
        in space: CoupleSpace,
        questions: [CatalogGameQuestion],
        catalogVersion: String,
        by userRecordName: String,
        now: Date = .now,
        using generator: inout Generator
    ) throws -> GameRound {
        if let open = openRound(in: space) { return open }
        let used = rounds(in: space)
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .flatMap { snapshots(of: $0).map(\.id) }
        let picked = GameRules.pickQuestions(from: questions, recentlyUsed: used, using: &generator)
        let round = GameRound(context: context)
        assignStore(round, like: space)
        round.id = UUID()
        round.questionsJSON = GameRules.encode(picked.map(GameQuestionSnapshot.init))
        round.catalogVersion = catalogVersion
        round.createdAt = now
        round.createdBy = userRecordName
        round.space = space
        try persistence.save()
        return round
    }

    func snapshots(of round: GameRound) -> [GameQuestionSnapshot] {
        GameRules.decode([GameQuestionSnapshot].self, from: round.questionsJSON) ?? []
    }

    func entries(of answer: GameAnswer?) -> [GameEntry] {
        GameRules.decode([GameEntry].self, from: answer?.entriesJSON) ?? []
    }

    /// Sends the current user's choices and guesses for `round`, once.
    @discardableResult
    func submitGame(_ entries: [GameEntry], for round: GameRound, by userRecordName: String, now: Date = .now) throws -> GameAnswer {
        if let existing = gameAnswer(for: round, by: userRecordName) { return existing }
        guard let space = round.space else { throw MomentsError.roundFinished }
        let answer = GameAnswer(context: context)
        assignStore(answer, like: space)
        answer.id = UUID()
        answer.roundID = round.id
        answer.authorID = userRecordName
        answer.entriesJSON = GameRules.encode(entries)
        answer.submittedAt = now
        answer.space = space
        try persistence.save()
        return answer
    }

    /// The creator gives up a round nobody finished; answers already sent stay stored.
    func cancelRound(_ round: GameRound, by userRecordName: String, now: Date = .now) throws {
        guard round.createdBy == userRecordName else { throw MomentsError.notAuthor }
        guard !isFinished(round) else { throw MomentsError.roundFinished }
        round.cancelledAt = now
        try persistence.save()
    }

    // MARK: Dates

    func plans(in space: CoupleSpace) -> [DatePlan] {
        let request = DatePlan.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND deletedAt == nil", space)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DatePlan.createdAt, ascending: false)]
        return fetch(request)
    }

    /// An open plan (not done, not deleted) for the same idea, so "Vamos fazer" twice
    /// does not create two plans.
    func openPlan(for candidate: DateCandidate, in space: CoupleSpace) -> DatePlan? {
        Canonical.pick(
            plans(in: space).filter {
                $0.completedAt == nil && $0.sourceKind == candidate.kind.rawValue && $0.sourceID == candidate.sourceID
                    && $0.invitation != DateInvitation.declined.rawValue && $0.invitation != DateInvitation.cancelled.rawValue
            },
            createdAt: \.createdAt,
            id: \.id
        )
    }

    /// "Vamos fazer" (`invite` false) or "Convidar meu par" (`invite` true). Reuses the open
    /// plan of the same idea; inviting on an existing plan turns it into an invitation.
    @discardableResult
    func plan(_ candidate: DateCandidate, invite: Bool, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> DatePlan {
        let plan: DatePlan
        if let existing = openPlan(for: candidate, in: space) {
            plan = existing
        } else {
            plan = DatePlan(context: context)
            assignStore(plan, like: space)
            plan.id = UUID()
            plan.sourceKind = candidate.kind.rawValue
            plan.sourceID = candidate.sourceID
            plan.title = candidate.title
            plan.details = candidate.details
            plan.createdAt = now
            plan.createdBy = userRecordName
            plan.space = space
        }
        if invite, plan.invitation == nil {
            setInvitation(.pending, on: plan, by: userRecordName, now: now)
        }
        plan.modifiedAt = now
        plan.modifiedBy = userRecordName
        try persistence.save()
        return plan
    }

    /// The invited partner accepts or declines; the inviter cancels. Updates the same plan.
    func respond(to plan: DatePlan, accept: Bool, by userRecordName: String, now: Date = .now) throws {
        guard plan.createdBy != userRecordName, plan.invitation == DateInvitation.pending.rawValue else { return }
        setInvitation(accept ? .accepted : .declined, on: plan, by: userRecordName, now: now)
        try persistence.save()
    }

    func cancelInvitation(_ plan: DatePlan, by userRecordName: String, now: Date = .now) throws {
        guard plan.createdBy == userRecordName, plan.invitation == DateInvitation.pending.rawValue else { return }
        setInvitation(.cancelled, on: plan, by: userRecordName, now: now)
        try persistence.save()
    }

    /// Marks the date as done. Does not create a memory nor change a saved place.
    func complete(_ plan: DatePlan, by userRecordName: String, now: Date = .now) throws {
        guard plan.completedAt == nil else { return }
        plan.completedAt = now
        plan.completedBy = userRecordName
        plan.modifiedAt = now
        plan.modifiedBy = userRecordName
        try persistence.save()
    }

    func linkMemory(_ memoryID: UUID?, to plan: DatePlan) throws {
        guard plan.memoryID == nil, let memoryID else { return }
        plan.memoryID = memoryID
        try persistence.save()
    }

    func softDelete(_ plan: DatePlan, by userRecordName: String, now: Date = .now) throws {
        plan.deletedAt = now
        plan.deletedBy = userRecordName
        plan.modifiedAt = now
        plan.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ plan: DatePlan, by userRecordName: String, now: Date = .now) throws {
        plan.deletedAt = nil
        plan.deletedBy = nil
        plan.modifiedAt = now
        plan.modifiedBy = userRecordName
        try persistence.save()
    }

    private func setInvitation(_ invitation: DateInvitation, on plan: DatePlan, by userRecordName: String, now: Date) {
        plan.invitation = invitation.rawValue
        plan.invitationChangedAt = now
        plan.invitationChangedBy = userRecordName
        plan.modifiedAt = now
        plan.modifiedBy = userRecordName
    }

    // MARK: Own ideas

    func ideas(in space: CoupleSpace) -> [DateIdea] {
        let request = DateIdea.fetchRequest()
        request.predicate = NSPredicate(format: "space == %@ AND deletedAt == nil", space)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DateIdea.createdAt, ascending: false)]
        return fetch(request)
    }

    @discardableResult
    func createIdea(_ draft: DateIdeaDraft, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> DateIdea {
        guard draft.isValid else { throw MomentsError.invalidIdea }
        let idea = DateIdea(context: context)
        assignStore(idea, like: space)
        idea.id = UUID()
        idea.authorID = userRecordName
        idea.createdAt = now
        idea.space = space
        apply(draft, to: idea, by: userRecordName, now: now)
        try persistence.save()
        return idea
    }

    func updateIdea(_ idea: DateIdea, with draft: DateIdeaDraft, by userRecordName: String, now: Date = .now) throws {
        guard idea.authorID == userRecordName else { throw MomentsError.notAuthor }
        guard draft.isValid else { throw MomentsError.invalidIdea }
        apply(draft, to: idea, by: userRecordName, now: now)
        try persistence.save()
    }

    func softDeleteIdea(_ idea: DateIdea, by userRecordName: String, now: Date = .now) throws {
        guard idea.authorID == userRecordName else { throw MomentsError.notAuthor }
        idea.deletedAt = now
        idea.deletedBy = userRecordName
        idea.modifiedAt = now
        idea.modifiedBy = userRecordName
        try persistence.save()
    }

    func restoreIdea(_ idea: DateIdea, by userRecordName: String, now: Date = .now) throws {
        guard idea.authorID == userRecordName else { throw MomentsError.notAuthor }
        idea.deletedAt = nil
        idea.deletedBy = nil
        idea.modifiedAt = now
        idea.modifiedBy = userRecordName
        try persistence.save()
    }

    static func draft(from idea: DateIdea) -> DateIdeaDraft {
        DateIdeaDraft(
            title: idea.title ?? "",
            details: idea.details ?? "",
            location: idea.location.flatMap(DateLocation.init(rawValue:)) ?? .flexivel,
            cost: idea.costTier.flatMap(DateCost.init(rawValue:)) ?? .aConfirmar,
            durationMinutes: idea.durationMinutes > 0 ? Int(idea.durationMinutes) : nil,
            remoteFriendly: idea.remoteFriendly
        )
    }

    static func candidate(from idea: DateIdea) -> DateCandidate? {
        guard let id = idea.id else { return nil }
        let draft = draft(from: idea)
        return DateCandidate(
            kind: .idea,
            sourceID: id.uuidString,
            title: draft.trimmedTitle,
            details: draft.details.trimmed.isEmpty ? nil : draft.details.trimmed,
            location: draft.location,
            cost: draft.cost,
            durationMinutes: draft.durationMinutes,
            remoteFriendly: draft.remoteFriendly
        )
    }

    private func apply(_ draft: DateIdeaDraft, to idea: DateIdea, by userRecordName: String, now: Date) {
        idea.title = draft.trimmedTitle
        let details = draft.details.trimmed
        idea.details = details.isEmpty ? nil : details
        idea.location = draft.location.rawValue
        idea.costTier = draft.cost.rawValue
        idea.durationMinutes = Int64(draft.durationMinutes ?? 0)
        idea.remoteFriendly = draft.remoteFriendly
        idea.modifiedAt = now
        idea.modifiedBy = userRecordName
    }
}
