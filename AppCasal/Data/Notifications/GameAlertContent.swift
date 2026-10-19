//
//  GameAlertContent.swift
//  AppCasal
//
//  Compiled in the app and in the NoteNotificationService extension.
//

import CloudKit
import Foundation

/// Turns the "Quem conhece melhor?" answer records fetched by the notification extension
/// into the alert text: the partner finished a round, so it is this person's turn (or
/// the result is ready). Never shows choices or guesses.
nonisolated enum GameAlertContent {
    static let subscriptionID = "game-alerts-v1"
    /// Core Data prefixes mirrored record types and fields with `CD_`.
    static let recordType = "CD_GameAnswer"
    static let desiredKeys: [CKRecord.FieldKey] = ["CD_authorID", "CD_roundID", "CD_submittedAt"]
    /// Changes older than this are not the reason for the push being handled.
    static let recentWindow: TimeInterval = 15 * 60
    /// `MomentsRoute.game` payload, opened by a tap.
    static let route = "game"

    static var title: String { String(localized: "Quem conhece melhor?") }
    /// Shown as is when the extension cannot tell what changed.
    static var fallbackBody: String { String(localized: "Tem novidade no quiz de vocês. Toque para ver.") }

    struct Answer: Equatable, Sendable {
        var authorID: String
        var roundID: String
        var submittedAt: Date
    }

    enum Event: Equatable, Sendable {
        /// The partner finished; `waitingForMe` when this person has not played that round.
        case partnerFinished(roundID: String, waitingForMe: Bool)
        /// This person's own answers (the server did not skip this device).
        case ownFinished(roundID: String)
    }

    static func answer(from record: CKRecord) -> Answer? {
        guard record.recordType == recordType,
              let authorID = record["CD_authorID"] as? String,
              let submittedAt = record["CD_submittedAt"] as? Date else { return nil }
        // Core Data mirrors UUID attributes as strings.
        let roundID = (record["CD_roundID"] as? String) ?? (record["CD_roundID"] as? UUID)?.uuidString
        guard let roundID else { return nil }
        return Answer(authorID: authorID, roundID: roundID.lowercased(), submittedAt: submittedAt)
    }

    /// Rounds this person played, from every answer seen so far.
    static func playedRounds(_ answers: [Answer], me: String, known: Set<String>) -> Set<String> {
        known.union(answers.filter { $0.authorID == me }.map(\.roundID))
    }

    static func event(in answers: [Answer], me: String, playedByMe: Set<String>, now: Date) -> Event? {
        let recent = answers.filter { abs(now.timeIntervalSince($0.submittedAt)) <= recentWindow }
        if let partner = recent.filter({ $0.authorID != me }).max(by: { $0.submittedAt < $1.submittedAt }) {
            return .partnerFinished(roundID: partner.roundID, waitingForMe: !playedByMe.contains(partner.roundID))
        }
        return recent.max { $0.submittedAt < $1.submittedAt }.map { .ownFinished(roundID: $0.roundID) }
    }

    static func body(for event: Event, partnerName: String) -> String {
        let name = partnerName.isEmpty ? String(localized: "Seu par") : partnerName
        switch event {
        case .partnerFinished(_, true):
            return String(localized: "Um novo quiz foi iniciado! \(name) já respondeu. Toque para responder.")
        case .partnerFinished(_, false):
            return String(localized: "\(name) terminou o quiz. O resultado de vocês está pronto!")
        case .ownFinished:
            return String(localized: "Suas respostas foram enviadas. Quando \(name) terminar, o resultado aparece.")
        }
    }

    /// Database scope of a push from the game alert subscription; nil for other pushes.
    static func databaseScope(of userInfo: [AnyHashable: Any]) -> CKDatabase.Scope? {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notification.subscriptionID == subscriptionID else { return nil }
        return notification.databaseScope
    }
}
