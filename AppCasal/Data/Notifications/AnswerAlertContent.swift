//
//  AnswerAlertContent.swift
//  AppCasal
//
//  Compiled in the app and in the NoteNotificationService extension.
//

import CloudKit
import Foundation

/// Turns the daily answer records fetched by the notification extension into the alert
/// text of "seu par respondeu". The database subscription push carries no record
/// fields, so the extension fetches the changed answers. Never shows an answer's text:
/// answers are revealed only inside the app, once both have answered.
nonisolated enum AnswerAlertContent {
    static let subscriptionID = "answer-alerts-v1"
    /// Core Data prefixes mirrored record types and fields with `CD_`.
    static let recordType = "CD_DailyAnswer"
    static let desiredKeys: [CKRecord.FieldKey] = ["CD_authorID", "CD_dayKey", "CD_questionText", "CD_submittedAt", "CD_reactedAt"]
    /// Changes older than this are not the reason for the push being handled.
    static let recentWindow: TimeInterval = 15 * 60
    static let maximumQuestionLength = 120
    /// Same key as `MomentNotifications.routeKey`: a tap opens that day's question.
    static let routeKey = "momentsRoute"

    static var title: String { String(localized: "Hoje, nós dois") }
    /// Shown as is when the extension cannot tell what changed.
    static var fallbackBody: String { String(localized: "Tem novidade na pergunta do dia. Toque para ver.") }

    struct Answer: Equatable, Sendable {
        var authorID: String
        var dayKey: String
        var questionText: String?
        var submittedAt: Date
        var reactedAt: Date?
    }

    /// Why the push was sent, as far as the changed answers tell.
    enum Event: Equatable, Sendable {
        /// The partner answered; `waitingForMe` when this person has not answered that day.
        case partnerAnswered(dayKey: String, question: String?, waitingForMe: Bool)
        /// The partner reacted to that day's discovery.
        case partnerReacted(dayKey: String)
        /// This person's own answer (the server did not skip this device).
        case ownAnswer(dayKey: String)
    }

    static func answer(from record: CKRecord) -> Answer? {
        guard record.recordType == recordType,
              let authorID = record["CD_authorID"] as? String,
              let dayKey = record["CD_dayKey"] as? String,
              let submittedAt = record["CD_submittedAt"] as? Date else { return nil }
        return Answer(
            authorID: authorID,
            dayKey: dayKey,
            questionText: record["CD_questionText"] as? String,
            submittedAt: submittedAt,
            reactedAt: record["CD_reactedAt"] as? Date
        )
    }

    /// Days this person answered, from every answer seen so far (kept by the extension,
    /// since the change feed brings each answer once).
    static func answeredDays(_ answers: [Answer], me: String, known: Set<String>) -> Set<String> {
        known.union(answers.filter { $0.authorID == me }.map(\.dayKey))
    }

    /// The most recent event among the changed answers, or nil when none is recent.
    static func event(in answers: [Answer], me: String, answeredByMe: Set<String>, now: Date) -> Event? {
        func isRecent(_ date: Date?) -> Bool {
            guard let date else { return false }
            return now.timeIntervalSince(date) <= recentWindow && now.timeIntervalSince(date) >= -recentWindow
        }
        var candidates: [(date: Date, event: Event)] = []
        for answer in answers {
            if answer.authorID == me {
                if isRecent(answer.submittedAt) {
                    candidates.append((answer.submittedAt, .ownAnswer(dayKey: answer.dayKey)))
                }
                continue
            }
            if isRecent(answer.submittedAt) {
                candidates.append((answer.submittedAt, .partnerAnswered(
                    dayKey: answer.dayKey,
                    question: answer.questionText,
                    waitingForMe: !answeredByMe.contains(answer.dayKey)
                )))
            } else if let reactedAt = answer.reactedAt, isRecent(reactedAt) {
                candidates.append((reactedAt, .partnerReacted(dayKey: answer.dayKey)))
            }
        }
        // The partner's news first; this person's own answer only when nothing else.
        let partnerEvents = candidates.filter { if case .ownAnswer = $0.event { false } else { true } }
        return (partnerEvents.isEmpty ? candidates : partnerEvents).max { $0.date < $1.date }?.event
    }

    static func body(for event: Event, partnerName: String) -> String {
        let name = partnerName.isEmpty ? String(localized: "Seu par") : partnerName
        switch event {
        case .partnerAnswered(_, _, true):
            return String(localized: "\(name) respondeu à pergunta do dia e está esperando a sua resposta.")
        case .partnerAnswered(_, _, false):
            return String(localized: "\(name) respondeu à pergunta do dia. Vejam as respostas de vocês!")
        case .partnerReacted:
            return String(localized: "\(name) reagiu às respostas de hoje.")
        case .ownAnswer:
            return String(localized: "Sua resposta foi enviada. Quando \(name) responder, vocês veem as duas.")
        }
    }

    /// The question, under the title, when the partner answered.
    static func subtitle(for event: Event) -> String? {
        guard case .partnerAnswered(_, let question?, _) = event else { return nil }
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count > maximumQuestionLength ? String(text.prefix(maximumQuestionLength - 1)) + "…" : text
    }

    /// `MomentsRoute.daily(dayKey:)` payload, opened by a tap.
    static func route(for event: Event) -> String {
        switch event {
        case .partnerAnswered(let dayKey, _, _), .partnerReacted(let dayKey), .ownAnswer(let dayKey):
            "daily:\(dayKey)"
        }
    }

    /// Database scope of a push from the answer alert subscription; nil for other pushes.
    static func databaseScope(of userInfo: [AnyHashable: Any]) -> CKDatabase.Scope? {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notification.subscriptionID == subscriptionID else { return nil }
        return notification.databaseScope
    }
}
