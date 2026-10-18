//
//  MomentsRulesTests.swift
//  AppCasalTests
//

import Foundation
import Testing
@testable import AppCasal

/// Deterministic generator so draws are repeatable in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct MomentsRulesTests {
    private let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func questions() throws -> [CatalogQuestion] { try MomentsCatalog.load().questions }

    // MARK: Calendar

    @Test func dayKeyUsesTheSpaceTimeZoneNotTheDevice() throws {
        // 2026-10-18 23:30 in São Paulo is already the 19th in Tokyo.
        let date = try #require(MomentsCalendar.calendar(in: saoPaulo).date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 23, minute: 30)))
        #expect(MomentsCalendar.dayKey(for: date, in: saoPaulo) == "2026-10-18")
        #expect(MomentsCalendar.dayKey(for: date, in: tokyo) == "2026-10-19")
    }

    @Test func dayKeysSurviveDaylightSavingChanges() throws {
        // New York springs forward on 2026-03-08.
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let start = try #require(MomentsCalendar.calendar(in: newYork).date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 0, minute: 10)))
        #expect(MomentsCalendar.dayKeys(startingAt: start, count: 3, in: newYork) == ["2026-03-07", "2026-03-08", "2026-03-09"])
        let back = try #require(MomentsCalendar.date(forDayKey: "2026-03-08", in: newYork))
        #expect(MomentsCalendar.dayKey(for: back, in: newYork) == "2026-03-08")
    }

    // MARK: Planner

    @Test func plannerAlternatesThemesWithoutRepeating() throws {
        let questions = try questions()
        let days = (1...20).map { String(format: "2026-11-%02d", $0) }
        let plan = DailyQuestionPlanner.plan(days: days, existing: [], questions: questions)
        #expect(plan.count == 20)
        #expect(Set(plan.map(\.question.id)).count == 20)
        for (index, item) in plan.enumerated() {
            #expect(item.question.category == QuestionCategory.allCases[index % 5])
            #expect(item.cycle == 0)
        }
    }

    @Test func plannerIsDeterministicAndKeepsAssignedDays() throws {
        let questions = try questions()
        let existing = [QuestionAssignment(dayKey: "2026-11-01", questionID: "question-004", cycle: 0)]
        let days = ["2026-11-01", "2026-11-02", "2026-11-03"]
        let first = DailyQuestionPlanner.plan(days: days, existing: existing, questions: questions)
        let second = DailyQuestionPlanner.plan(days: days, existing: existing, questions: questions)
        #expect(first.map(\.dayKey) == ["2026-11-02", "2026-11-03"])
        #expect(first.map(\.question.id) == second.map(\.question.id))
        // question-004 is "carinho": next is "futuro".
        #expect(first.first?.question.category == .futuro)
    }

    @Test func plannerStartsANewCycleAfterUsingEveryQuestion() throws {
        let questions = Array(try questions().prefix(5))
        let existing = questions.enumerated().map { QuestionAssignment(dayKey: String(format: "2026-11-%02d", $0.offset + 1), questionID: $0.element.id, cycle: 0) }
        let plan = DailyQuestionPlanner.plan(days: ["2026-11-06"], existing: existing, questions: questions)
        #expect(plan.first?.cycle == 1)
        #expect(plan.first?.question.id == questions[0].id)
    }

    @Test func plannerNeverFillsDaysBeforeTheLastAssigned() throws {
        let existing = [QuestionAssignment(dayKey: "2026-11-10", questionID: "question-001", cycle: 0)]
        let plan = DailyQuestionPlanner.plan(days: ["2026-11-05", "2026-11-11"], existing: existing, questions: try questions())
        #expect(plan.map(\.dayKey) == ["2026-11-11"])
    }

    @Test func canonicalPickIsTheSameInAnyOrder() {
        struct Item { let createdAt: Date?; let id: UUID? }
        let early = Item(createdAt: Date(timeIntervalSince1970: 10), id: UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000"))
        let tieLow = Item(createdAt: Date(timeIntervalSince1970: 20), id: UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let tieHigh = Item(createdAt: Date(timeIntervalSince1970: 20), id: UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(Canonical.pick([tieHigh, early, tieLow], createdAt: \.createdAt, id: \.id)?.id == early.id)
        #expect(Canonical.pick([tieHigh, tieLow], createdAt: \.createdAt, id: \.id)?.id == tieLow.id)
        #expect(Canonical.pick([tieLow, tieHigh], createdAt: \.createdAt, id: \.id)?.id == tieLow.id)
    }

    // MARK: Dates

    @Test func filtersAreIndependentAndUnknownsNeverPassRestrictions() throws {
        let catalog = try MomentsCatalog.load()
        let all = catalog.dates.map(DateCandidate.init)
        let place = DateCandidate(placeID: UUID(), name: "Mirante", note: nil)

        var filters = DateFilters(sources: [.catalog, .place])
        filters.cost = .noExtraCost
        #expect(DateDraw.eligible(all, filters: filters).allSatisfy { $0.cost == .semGastoAdicional })
        #expect(!filters.matches(place))

        filters = DateFilters(sources: [.catalog, .place])
        filters.duration = .upTo60
        #expect(DateDraw.eligible(all, filters: filters).allSatisfy { ($0.durationMinutes ?? .max) <= 60 })
        #expect(!filters.matches(place))

        filters = DateFilters(sources: [.catalog, .place])
        filters.location = .home
        #expect(DateDraw.eligible(all, filters: filters).allSatisfy { $0.location == .casa || $0.location == .flexivel })
        #expect(!filters.matches(place))

        filters = DateFilters(sources: [.catalog, .place])
        filters.remoteOnly = true
        let remote = DateDraw.eligible(all, filters: filters)
        #expect(remote.count == 10)
        #expect(!filters.matches(place))

        // "Qualquer custo" accepts variable and unknown costs.
        #expect(DateFilters(sources: [.place]).matches(place))
    }

    @Test func drawDoesNotRepeatUntilExhausted() throws {
        let candidates = Array(try MomentsCatalog.load().dates.prefix(6)).map(DateCandidate.init)
        var generator = SeededGenerator(seed: 7)
        var shown = Set<String>()
        for _ in 0..<6 {
            let next = try #require(DateDraw.next(from: candidates, excluding: shown, using: &generator))
            #expect(shown.insert(next.id).inserted)
        }
        #expect(DateDraw.next(from: candidates, excluding: shown, using: &generator) == nil)
    }

    @Test func mixedSourcesDropDuplicatesByTitle() {
        let placeID = UUID()
        let place = DateCandidate(placeID: placeID, name: "Mirante", note: nil)
        let idea = DateCandidate(kind: .idea, sourceID: UUID().uuidString, title: " mirante ", details: nil, location: .fora, cost: .aConfirmar, durationMinutes: nil, remoteFriendly: false)
        let eligible = DateDraw.eligible([place, idea, place], filters: DateFilters(sources: [.place, .idea]))
        #expect(eligible == [place])
    }

    @Test func ideaDraftValidation() {
        var draft = DateIdeaDraft(title: "Cinema em casa")
        #expect(draft.isValid)
        draft.durationMinutes = 2
        #expect(!draft.isValid)
        draft.durationMinutes = 90
        draft.location = .fora
        draft.remoteFriendly = true
        #expect(!draft.isValid, "out-of-home ideas are not remote")
        draft.remoteFriendly = false
        draft.title = String(repeating: "a", count: 81)
        #expect(!draft.isValid)
        draft.title = "   "
        #expect(!draft.isValid)
    }

    // MARK: Game

    @Test func roundPicksFiveDistinctQuestionsPreferringUnused() throws {
        let questions = try MomentsCatalog.load().gameQuestions
        var generator = SeededGenerator(seed: 3)
        let used = questions.prefix(55).map(\.id)
        let picked = GameRules.pickQuestions(from: questions, recentlyUsed: Array(used), using: &generator)
        #expect(picked.count == 5)
        #expect(Set(picked.map(\.id)) == Set(questions.suffix(5).map(\.id)))
    }

    @Test func scoreComparesIDsAndSkipsDoNotCount() {
        let mine = [
            GameEntry(questionID: "game-001", selfOptionID: "option-1", guessOptionID: "option-2"),
            GameEntry(questionID: "game-002", selfOptionID: nil, guessOptionID: "option-3"),
            GameEntry(questionID: "game-003", selfOptionID: "option-4", guessOptionID: nil),
        ]
        let partner = [
            GameEntry(questionID: "game-001", selfOptionID: "option-2", guessOptionID: "option-1"),
            GameEntry(questionID: "game-002", selfOptionID: "option-1", guessOptionID: nil),
            GameEntry(questionID: "game-003", selfOptionID: nil, guessOptionID: "option-4"),
        ]
        #expect(GameRules.score(guesser: mine, chooser: partner) == GameScore(correct: 1, compared: 2))
        #expect(GameRules.score(guesser: partner, chooser: mine) == GameScore(correct: 2, compared: 2))
        let allSkipped = [GameEntry(questionID: "game-001", selfOptionID: nil, guessOptionID: nil)]
        #expect(GameRules.score(guesser: allSkipped, chooser: allSkipped) == GameScore(correct: 0, compared: 0))
    }

    @Test func roundSnapshotRoundTrips() throws {
        let question = try #require(try MomentsCatalog.load().gameQuestions.first)
        let json = try #require(GameRules.encode([GameQuestionSnapshot(question)]))
        let decoded = try #require(GameRules.decode([GameQuestionSnapshot].self, from: json))
        #expect(decoded.first?.options.map(\.id) == question.options.map(\.id))
    }

    // MARK: Gestures and revive

    @Test func gestureAvoidsRecentOnes() throws {
        let gestures = Array(try MomentsCatalog.load().gestures.prefix(4))
        var generator = SeededGenerator(seed: 1)
        let recent = gestures.prefix(3).map(\.id)
        #expect(GestureRules.next(from: gestures, recent: recent, using: &generator)?.id == gestures[3].id)
        // All recent: still offers something other than the current one.
        let other = GestureRules.next(from: gestures, recent: gestures.map(\.id), excluding: gestures[0].id, using: &generator)
        #expect(other != nil && other?.id != gestures[0].id)
    }

    @Test func reviveFindsAnniversariesIncludingLeapDay() throws {
        let calendar = MomentsCalendar.calendar(in: saoPaulo)
        func day(_ y: Int, _ m: Int, _ d: Int) throws -> Date { try #require(calendar.date(from: DateComponents(year: y, month: m, day: d))) }
        let leap = ReviveCandidate(id: UUID(), date: try day(2024, 2, 29))
        let lastYear = ReviveCandidate(id: UUID(), date: try day(2025, 10, 18))
        let today = ReviveCandidate(id: UUID(), date: try day(2026, 10, 18))

        let onLeap = ReviveRules.suggestion(from: [leap, today], recent: [], today: try day(2027, 2, 28), calendar: calendar)
        #expect(onLeap == ReviveSuggestion(id: leap.id, yearsAgo: 3))

        let anniversary = ReviveRules.suggestion(from: [today, lastYear], recent: [], today: try day(2026, 10, 18), calendar: calendar)
        #expect(anniversary == ReviveSuggestion(id: lastYear.id, yearsAgo: 1))

        // A memory from today is never "a year ago", nor offered as old.
        #expect(ReviveRules.suggestion(from: [today], recent: [], today: try day(2026, 10, 18), calendar: calendar) == nil)
    }

    @Test func reviveSkipsRecentSuggestions() throws {
        let calendar = MomentsCalendar.calendar(in: saoPaulo)
        let old = ReviveCandidate(id: UUID(), date: try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))))
        let older = ReviveCandidate(id: UUID(), date: try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18)))
        #expect(ReviveRules.suggestion(from: [old, older], recent: [older.id], today: today, calendar: calendar)?.id == old.id)
    }
}
