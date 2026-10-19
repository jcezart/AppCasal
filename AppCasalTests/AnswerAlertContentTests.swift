//
//  AnswerAlertContentTests.swift
//  AppCasalTests
//

import CloudKit
import Foundation
import Testing
@testable import AppCasal

struct AnswerAlertContentTests {
    private let me = "_me"
    private let partner = "_partner"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func answer(by author: String, day: String = "2026-10-19", minutesAgo: Double, reactedMinutesAgo: Double? = nil) -> AnswerAlertContent.Answer {
        AnswerAlertContent.Answer(
            authorID: author,
            dayKey: day,
            questionText: "Qual música lembra nós dois?",
            submittedAt: now.addingTimeInterval(-minutesAgo * 60),
            reactedAt: reactedMinutesAgo.map { now.addingTimeInterval(-$0 * 60) }
        )
    }

    @Test func partnerAnsweredWaitsForMeWhenIHaveNotAnswered() throws {
        let event = try #require(AnswerAlertContent.event(in: [answer(by: partner, minutesAgo: 1)], me: me, answeredByMe: [], now: now))
        #expect(event == .partnerAnswered(dayKey: "2026-10-19", question: "Qual música lembra nós dois?", waitingForMe: true))
        #expect(AnswerAlertContent.body(for: event, partnerName: "Ana") == "Ana respondeu à pergunta do dia e está esperando a sua resposta.")
        #expect(AnswerAlertContent.subtitle(for: event) == "Qual música lembra nós dois?")
        #expect(AnswerAlertContent.route(for: event) == MomentsRoute.daily(dayKey: "2026-10-19").payload)
    }

    @Test func partnerAnsweredAfterMeRevealsBoth() throws {
        // My answer came in an earlier push; the extension remembers the day.
        let answered = AnswerAlertContent.answeredDays([answer(by: me, minutesAgo: 300)], me: me, known: ["2026-10-18"])
        #expect(answered == ["2026-10-18", "2026-10-19"])
        let event = try #require(AnswerAlertContent.event(in: [answer(by: partner, minutesAgo: 1)], me: me, answeredByMe: answered, now: now))
        #expect(AnswerAlertContent.body(for: event, partnerName: "Ana") == "Ana respondeu à pergunta do dia. Vejam as respostas de vocês!")
    }

    @Test func reactionIsNotAnAnswer() throws {
        let event = try #require(AnswerAlertContent.event(in: [answer(by: partner, minutesAgo: 600, reactedMinutesAgo: 2)], me: me, answeredByMe: [], now: now))
        #expect(event == .partnerReacted(dayKey: "2026-10-19"))
        #expect(AnswerAlertContent.subtitle(for: event) == nil)
    }

    @Test func ownAnswerOnlyWhenNothingFromThePartner() throws {
        let own = try #require(AnswerAlertContent.event(in: [answer(by: me, minutesAgo: 1)], me: me, answeredByMe: [], now: now))
        #expect(own == .ownAnswer(dayKey: "2026-10-19"))
        let both = AnswerAlertContent.event(in: [answer(by: me, minutesAgo: 1), answer(by: partner, minutesAgo: 3)], me: me, answeredByMe: ["2026-10-19"], now: now)
        #expect(both == .partnerAnswered(dayKey: "2026-10-19", question: "Qual música lembra nós dois?", waitingForMe: false))
    }

    @Test func oldChangesAreNotTheReason() {
        #expect(AnswerAlertContent.event(in: [answer(by: partner, minutesAgo: 60)], me: me, answeredByMe: [], now: now) == nil)
    }

    @Test func readsMirroredRecordsAndRecognizesItsPushes() throws {
        let record = CKRecord(recordType: AnswerAlertContent.recordType)
        record["CD_authorID"] = partner
        record["CD_dayKey"] = "2026-10-19"
        record["CD_submittedAt"] = now
        record["CD_text"] = "segredo"
        let parsed = try #require(AnswerAlertContent.answer(from: record))
        #expect(parsed.authorID == partner && parsed.dayKey == "2026-10-19")
        #expect(!AnswerAlertContent.desiredKeys.contains("CD_text"), "the answer text never reaches the extension")
        #expect(AnswerAlertContent.answer(from: CKRecord(recordType: NoteAlertContent.recordType)) == nil)
        #expect(AnswerAlertContent.databaseScope(of: ["aps": [:]]) == nil)
        let subscription = AnswerAlerts.makeSubscription(partnerName: "Ana")
        #expect(subscription.recordType == "CD_DailyAnswer")
        #expect(subscription.notificationInfo?.shouldSendMutableContent == true)
        #expect(subscription.notificationInfo?.subtitle == "Ana")
        #expect(subscription.subscriptionID != NoteAlerts.subscriptionID)
    }
}
