//
//  RemoteAlertPresentationTests.swift
//  AppCasalTests
//

import Foundation
import Testing
@testable import AppCasal

struct RemoteAlertPresentationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func partnerAnswerIsLoudAndObsoleteOnceIAnswer() {
        let alert = RemoteAlertPresentation.answer(.event(.partnerAnswered(dayKey: "2026-10-19", question: "Qual música?", waitingForMe: true)), partnerName: "Ana", spaceEndedIsRepeat: false)
        #expect(!alert.isQuiet)
        #expect(alert.body == "Ana respondeu à pergunta do dia e está esperando a sua resposta.")
        #expect(alert.subtitle == "Qual música?")
        #expect(alert.userInfo[AnswerAlertContent.routeKey] == "daily:2026-10-19")
        #expect(alert.userInfo[RemoteAlertPresentation.obsoleteDayKey] == "2026-10-19")
        let both = RemoteAlertPresentation.answer(.event(.partnerAnswered(dayKey: "2026-10-19", question: nil, waitingForMe: false)), partnerName: "Ana", spaceEndedIsRepeat: false)
        #expect(both.userInfo[RemoteAlertPresentation.obsoleteDayKey] == nil, "the reveal is news, kept after answering")
    }

    @Test func reactionsOwnChangesAndUpdatesAreQuiet() {
        #expect(RemoteAlertPresentation.answer(.event(.partnerReacted(dayKey: "2026-10-19")), partnerName: "Ana", spaceEndedIsRepeat: false).isQuiet)
        #expect(RemoteAlertPresentation.answer(.event(.ownAnswer(dayKey: "2026-10-19")), partnerName: "Ana", spaceEndedIsRepeat: false).isQuiet)
        #expect(RemoteAlertPresentation.answer(.irrelevant, partnerName: "Ana", spaceEndedIsRepeat: false).isQuiet)
        #expect(RemoteAlertPresentation.game(.event(.ownFinished(roundID: "r")), partnerName: "Ana", spaceEndedIsRepeat: false).isQuiet)
        #expect(RemoteAlertPresentation.note(.irrelevant, spaceEndedIsRepeat: false).isQuiet)
    }

    @Test func failedFetchKeepsTheGenericAlertAudible() {
        // Without network the push may still be real news: say it, generically.
        for alert in [
            RemoteAlertPresentation.note(.unknown, spaceEndedIsRepeat: false),
            RemoteAlertPresentation.answer(.unknown, partnerName: "Ana", spaceEndedIsRepeat: false),
            RemoteAlertPresentation.game(.unknown, partnerName: "Ana", spaceEndedIsRepeat: false),
        ] {
            #expect(!alert.isQuiet && alert.body == nil && alert.title == nil)
        }
    }

    @Test func spaceEndedIsSaidOnceAcrossSubscriptions() {
        #expect(!RemoteAlertPresentation.spaceEndedIsRepeat(lastShownAt: nil, now: now))
        #expect(RemoteAlertPresentation.spaceEndedIsRepeat(lastShownAt: now.addingTimeInterval(-5), now: now))
        #expect(!RemoteAlertPresentation.spaceEndedIsRepeat(lastShownAt: now.addingTimeInterval(-3600), now: now))
        let first = RemoteAlertPresentation.note(.spaceEnded, spaceEndedIsRepeat: false)
        let second = RemoteAlertPresentation.answer(.spaceEnded, partnerName: "Ana", spaceEndedIsRepeat: true)
        let third = RemoteAlertPresentation.game(.spaceEnded, partnerName: "Ana", spaceEndedIsRepeat: true)
        #expect(!first.isQuiet && second.isQuiet && third.isQuiet)
        #expect(Set([first.threadIdentifier, second.threadIdentifier, third.threadIdentifier]) == ["space"])
        #expect(second.body == first.body && second.subtitle == "")
    }

    @Test func quizTurnIsObsoleteOncePlayed() {
        let alert = RemoteAlertPresentation.game(.event(.partnerFinished(roundID: "abc", waitingForMe: true)), partnerName: "Ana", spaceEndedIsRepeat: false)
        #expect(!alert.isQuiet)
        #expect(alert.userInfo[RemoteAlertPresentation.obsoleteRoundKey] == "abc")
        #expect(alert.userInfo[AnswerAlertContent.routeKey] == GameAlertContent.route)
    }

    @Test func outOfOrderPushesNameTheLatestPartnerEvent() throws {
        // Two pushes coalesced into one fetch, records arriving in any order.
        let answers = [
            AnswerAlertContent.Answer(authorID: "p", dayKey: "2026-10-19", questionText: nil, submittedAt: now.addingTimeInterval(-60), reactedAt: now.addingTimeInterval(-10)),
            AnswerAlertContent.Answer(authorID: "me", dayKey: "2026-10-19", questionText: nil, submittedAt: now.addingTimeInterval(-30), reactedAt: nil),
        ]
        for order in [answers, answers.reversed()] {
            let answered = AnswerAlertContent.answeredDays(order, me: "me", known: [])
            let event = AnswerAlertContent.event(in: order, me: "me", answeredByMe: answered, now: now)
            #expect(event == .partnerAnswered(dayKey: "2026-10-19", question: nil, waitingForMe: false))
        }
    }
}
