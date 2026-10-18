//
//  MomentsRepositoryTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

struct MomentsRepositoryTests {
    private let owner = "_owner"
    private let partner = "_partner"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let zone = TimeZone(identifier: "America/Sao_Paulo")!

    private struct Fixture {
        let persistence: PersistenceController
        let spaces: SpaceRepository
        let moments: MomentsRepository
        let space: CoupleSpace
        let catalog: MomentsCatalog
    }

    private func fixture(withPartner: Bool = true) throws -> Fixture {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        if withPartner {
            try spaces.ensureMember(named: "Lucas", userRecordName: partner, in: space)
        }
        return Fixture(persistence: persistence, spaces: spaces, moments: MomentsRepository(persistence: persistence), space: space, catalog: try MomentsCatalog.load())
    }

    private func prepare(_ f: Fixture, at date: Date? = nil) throws -> Int {
        try f.moments.prepareDays(in: f.space, questions: f.catalog.questions, catalogVersion: f.catalog.questionsVersion, by: owner, now: date ?? now, timeZone: zone)
    }

    private func today(_ f: Fixture) throws -> DailyQuestion {
        let key = try #require(f.moments.todayKey(in: f.space, now: now))
        return try #require(f.moments.session(for: key, in: f.space))
    }

    // MARK: Daily question

    @Test func preparingDaysIsIdempotentAndSetsTheTimeZone() throws {
        let f = try fixture()
        #expect(try prepare(f) == DailyQuestionPlanner.daysAhead)
        #expect(f.space.momentsTimeZone == zone.identifier)
        #expect(try prepare(f) == 0)
        // A day later only the new last day is added; earlier days keep their question.
        let before = try today(f).questionID
        #expect(try prepare(f, at: now.addingTimeInterval(86_400)) == 1)
        #expect(try today(f).questionID == before)
        #expect(f.moments.allSessions(in: f.space).count == DailyQuestionPlanner.daysAhead + 1)
    }

    @Test func onlyTheOwnerPreparesDays() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let context = persistence.viewContext
        let shared = CoupleSpace(context: context)
        context.assign(shared, to: try #require(persistence.sharedStore))
        shared.id = UUID()
        try persistence.save()
        let catalog = try MomentsCatalog.load()
        #expect(throws: MomentsRepository.MomentsError.self) {
            try MomentsRepository(persistence: persistence).prepareDays(in: shared, questions: catalog.questions, catalogVersion: "1", by: partner, now: now)
        }
        #expect(shared.momentsTimeZone == nil)
    }

    @Test func answersRevealOnlyWhenBothSent() throws {
        let f = try fixture()
        _ = try prepare(f)
        let session = try today(f)
        #expect(f.moments.state(of: session, for: owner)?.isRevealed == false)

        try f.moments.submitAnswer("Um filme de comédia romântica", to: session, by: owner, now: now)
        let afterMine = try #require(f.moments.state(of: session, for: owner))
        #expect(afterMine.mine != nil && afterMine.partner == nil && !afterMine.isRevealed)
        // The partner sees the participation state, not the content (the view hides it).
        let partnerSide = try #require(f.moments.state(of: session, for: partner))
        #expect(partnerSide.mine == nil && partnerSide.partner != nil && !partnerSide.isRevealed)

        try f.moments.submitAnswer("Um documentário", to: session, by: partner, now: now)
        #expect(f.moments.state(of: session, for: owner)?.isRevealed == true)
        #expect(f.moments.state(of: session, for: partner)?.isRevealed == true)
    }

    @Test func sentAnswerIsFinalAndNeverDuplicated() throws {
        let f = try fixture()
        _ = try prepare(f)
        let session = try today(f)
        let first = try f.moments.submitAnswer("  Praia  ", to: session, by: owner, now: now)
        let again = try f.moments.submitAnswer("Praia", to: session, by: owner, now: now)
        #expect(first.objectID == again.objectID)
        #expect(throws: MomentsRepository.MomentsError.self) {
            try f.moments.submitAnswer("Montanha", to: session, by: owner, now: now)
        }
        #expect(f.moments.answers(for: try #require(session.dayKey), in: f.space).count == 1)
        #expect(throws: MomentsRepository.MomentsError.self) {
            try f.moments.submitAnswer("   ", to: session, by: partner, now: now)
        }
    }

    /// Two devices of the owner prepared the same day offline with different questions.
    /// Both partners must converge on one question, and no valid answer is deleted.
    @Test func duplicateSessionsReconcileDeterministically() throws {
        let f = try fixture()
        _ = try prepare(f)
        let canonical = try today(f)
        let dayKey = try #require(canonical.dayKey)

        let duplicate = DailyQuestion(context: f.persistence.viewContext)
        f.persistence.viewContext.assign(duplicate, to: try #require(f.space.objectID.persistentStore))
        duplicate.id = UUID()
        duplicate.dayKey = dayKey
        duplicate.questionID = "question-365"
        duplicate.questionText = "Outra pergunta"
        duplicate.createdAt = now.addingTimeInterval(5)
        duplicate.space = f.space
        try f.persistence.save()

        #expect(f.moments.session(for: dayKey, in: f.space)?.objectID == canonical.objectID)
        // An answer given on the duplicate stays stored, outside this discovery.
        let stray = try f.moments.submitAnswer("Resposta da outra", to: duplicate, by: partner, now: now)
        try f.moments.submitAnswer("Minha", to: canonical, by: owner, now: now)
        #expect(f.moments.state(of: canonical, for: owner)?.isRevealed == false)
        #expect(f.moments.answers(for: dayKey, in: f.space).contains { $0.objectID == stray.objectID })

        // Same creation time: the smaller ID wins on every device.
        duplicate.createdAt = canonical.createdAt
        try f.persistence.save()
        let expected = [canonical, duplicate].min { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
        #expect(f.moments.session(for: dayKey, in: f.space)?.objectID == expected?.objectID)
    }

    @Test func anotherSpaceNeverSeesThisSpaceRecords() throws {
        let f = try fixture()
        _ = try prepare(f)
        try f.moments.submitAnswer("Só nossa", to: try today(f), by: owner, now: now)
        let other = try f.spaces.createSpace(ownerName: "Bia", userRecordName: "_other")
        let key = try #require(f.moments.todayKey(in: f.space, now: now))
        #expect(f.moments.session(for: key, in: other) == nil)
        #expect(f.moments.answers(for: key, in: other).isEmpty)
        #expect(f.moments.history(in: other, untilDayKey: key).isEmpty)
    }

    @Test func savedMemoryIsLinkedOnce() throws {
        let f = try fixture()
        _ = try prepare(f)
        let session = try today(f)
        let first = UUID()
        try f.moments.linkMemory(first, to: session)
        try f.moments.linkMemory(UUID(), to: session)
        #expect(session.memoryID == first)
    }

    // MARK: Game

    @Test func roundStartsOnceAndFinishesWithBothAnswers() throws {
        let f = try fixture()
        var generator = SeededGenerator(seed: 9)
        let round = try f.moments.startRound(in: f.space, questions: f.catalog.gameQuestions, catalogVersion: "1", by: owner, now: now, using: &generator)
        let again = try f.moments.startRound(in: f.space, questions: f.catalog.gameQuestions, catalogVersion: "1", by: partner, now: now, using: &generator)
        #expect(round.objectID == again.objectID)
        let snapshots = f.moments.snapshots(of: round)
        #expect(snapshots.count == GameRules.roundSize)
        #expect(Set(snapshots.map(\.id)).count == GameRules.roundSize)

        let entries = snapshots.map { GameEntry(questionID: $0.id, selfOptionID: $0.options[0].id, guessOptionID: $0.options[1].id) }
        let mine = try f.moments.submitGame(entries, for: round, by: owner, now: now)
        #expect(try f.moments.submitGame([], for: round, by: owner, now: now).objectID == mine.objectID)
        #expect(!f.moments.isFinished(round))
        try f.moments.submitGame(entries, for: round, by: partner, now: now)
        #expect(f.moments.isFinished(round))
        #expect(f.moments.openRound(in: f.space) == nil)
        #expect(throws: MomentsRepository.MomentsError.self) { try f.moments.cancelRound(round, by: owner) }

        // The next round avoids the questions just played.
        let next = try f.moments.startRound(in: f.space, questions: f.catalog.gameQuestions, catalogVersion: "1", by: partner, now: now, using: &generator)
        #expect(Set(f.moments.snapshots(of: next).map(\.id)).isDisjoint(with: Set(snapshots.map(\.id))))
    }

    // MARK: Dates and ideas

    @Test func planningTwiceReusesThePlanAndInvitationIsAnsweredInPlace() throws {
        let f = try fixture()
        let candidate = DateCandidate(f.catalog.dates[0])
        let plan = try f.moments.plan(candidate, invite: false, in: f.space, by: owner, now: now)
        let invited = try f.moments.plan(candidate, invite: true, in: f.space, by: owner, now: now)
        #expect(plan.objectID == invited.objectID)
        #expect(invited.invitation == DateInvitation.pending.rawValue)
        #expect(plan.completedAt == nil)

        try f.moments.respond(to: invited, accept: true, by: owner)
        #expect(invited.invitation == DateInvitation.pending.rawValue, "the inviter cannot answer")
        try f.moments.respond(to: invited, accept: true, by: partner)
        #expect(invited.invitation == DateInvitation.accepted.rawValue)
        try f.moments.respond(to: invited, accept: false, by: partner)
        #expect(invited.invitation == DateInvitation.accepted.rawValue, "answered once")

        try f.moments.complete(invited, by: partner, now: now)
        #expect(invited.completedAt == now)
        #expect(f.moments.plans(in: f.space).count == 1)
    }

    @Test func choosingAPlaceDoesNotMarkItVisited() throws {
        let f = try fixture()
        let place = try PlaceRepository(persistence: f.persistence).create(
            PlaceDraft(name: "Mirante", address: "Lagoa", latitude: 0, longitude: 0, category: .special, status: .wishlist),
            in: f.space, by: owner
        )
        let candidate = DateCandidate(placeID: try #require(place.id), name: "Mirante", note: nil)
        let plan = try f.moments.plan(candidate, invite: false, in: f.space, by: owner, now: now)
        try f.moments.complete(plan, by: owner, now: now)
        #expect(place.status == PlaceStatus.wishlist.rawValue)
        #expect(place.visitedAt == nil)
    }

    @Test func ideasKeepTheirAuthor() throws {
        let f = try fixture()
        let idea = try f.moments.createIdea(DateIdeaDraft(title: "Piquenique", durationMinutes: 90), in: f.space, by: partner, now: now)
        #expect(idea.authorID == partner)
        #expect(f.moments.ideas(in: f.space).count == 1)
        #expect(throws: MomentsRepository.MomentsError.self) {
            try f.moments.updateIdea(idea, with: DateIdeaDraft(title: "Outro"), by: owner)
        }
        #expect(throws: MomentsRepository.MomentsError.self) {
            try f.moments.createIdea(DateIdeaDraft(title: ""), in: f.space, by: owner)
        }
        try f.moments.softDeleteIdea(idea, by: partner)
        #expect(f.moments.ideas(in: f.space).isEmpty)
        try f.moments.restoreIdea(idea, by: partner)
        #expect(MomentsRepository.candidate(from: idea)?.durationMinutes == 90)
    }

    @Test func localDraftsStayPerSpaceAndDevice() throws {
        let suite = "MomentsLocal-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = MomentsLocalStore(spaceID: UUID(), defaults: defaults)
        let second = MomentsLocalStore(spaceID: UUID(), defaults: defaults)
        first.setAnswerDraft("rascunho", for: "2026-10-18")
        #expect(first.answerDraft(for: "2026-10-18") == "rascunho")
        #expect(second.answerDraft(for: "2026-10-18").isEmpty)
        first.setAnswerDraft("  ", for: "2026-10-18")
        #expect(first.answerDraft(for: "2026-10-18").isEmpty)
    }
}
