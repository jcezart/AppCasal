//
//  GameAlertContentTests.swift
//  AppCasalTests
//

import CloudKit
import Foundation
import Testing
@testable import AppCasal

struct GameAlertContentTests {
    private let me = "_me"
    private let partner = "_partner"
    private let round = UUID().uuidString.lowercased()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func answer(by author: String, minutesAgo: Double) -> GameAlertContent.Answer {
        GameAlertContent.Answer(authorID: author, roundID: round, submittedAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    @Test func partnerFinishedFirstInvitesToPlay() throws {
        let event = try #require(GameAlertContent.event(in: [answer(by: partner, minutesAgo: 1)], me: me, playedByMe: [], now: now))
        #expect(event == .partnerFinished(roundID: round, waitingForMe: true))
        #expect(GameAlertContent.body(for: event, partnerName: "Ana") == "Um novo quiz foi iniciado! Ana já respondeu. Toque para responder.")
        #expect(MomentsRoute(payload: GameAlertContent.route) == .game)
    }

    @Test func partnerFinishedAfterMeShowsTheResult() throws {
        let played = GameAlertContent.playedRounds([answer(by: me, minutesAgo: 120)], me: me, known: [])
        let event = try #require(GameAlertContent.event(in: [answer(by: partner, minutesAgo: 1)], me: me, playedByMe: played, now: now))
        #expect(GameAlertContent.body(for: event, partnerName: "Ana") == "Ana terminou o quiz. O resultado de vocês está pronto!")
    }

    @Test func ownAnswersAndOldChangesAreNotThePartner() {
        #expect(GameAlertContent.event(in: [answer(by: me, minutesAgo: 1)], me: me, playedByMe: [], now: now) == .ownFinished(roundID: round))
        #expect(GameAlertContent.event(in: [answer(by: partner, minutesAgo: 60)], me: me, playedByMe: [], now: now) == nil)
    }

    @Test func readsMirroredRecordsWithoutTheChoices() throws {
        let record = CKRecord(recordType: GameAlertContent.recordType)
        record["CD_authorID"] = partner
        record["CD_roundID"] = round.uppercased()
        record["CD_submittedAt"] = now
        let parsed = try #require(GameAlertContent.answer(from: record))
        #expect(parsed.roundID == round)
        #expect(!GameAlertContent.desiredKeys.contains("CD_entriesJSON"))
        let subscription = AnswerAlerts.makeGameSubscription(partnerName: "Ana")
        #expect(subscription.recordType == "CD_GameAnswer")
        #expect(subscription.notificationInfo?.shouldSendMutableContent == true)
        #expect(subscription.subscriptionID != AnswerAlerts.subscriptionID)
    }
}
