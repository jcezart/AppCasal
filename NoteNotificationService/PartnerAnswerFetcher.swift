//
//  PartnerAnswerFetcher.swift
//  NoteNotificationService
//

import CloudKit
import Foundation
import OSLog

/// What a push from the answer alert subscription turned out to be.
enum AnswerAlertOutcome: Sendable {
    case event(AnswerAlertContent.Event)
    /// The shared space is gone (the database subscription also fires then).
    case spaceEnded
    /// Nothing to name (no network, an old change).
    case unknown
}

/// Fetches the daily answers changed since the last answer push. Change tokens of its
/// own (prefix `answers-`), so note pushes and answer pushes never consume each other's
/// changes. Remembers on which days this person answered, since the change feed brings
/// each answer only once.
enum PartnerAnswerFetcher {
    private static let log = Logger(subsystem: "jc.app.dev.AppCasal.NoteNotificationService", category: "answers")
    private static let answeredKey = "answers-answeredDays"
    /// Enough days to tell whether today's question is still waiting.
    private static let keptDays = 60

    static func outcome(in scope: CKDatabase.Scope, now: Date = .now) async -> AnswerAlertOutcome {
        let container = CKContainer(identifier: NoteAlertContent.containerIdentifier)
        let database = container.database(with: scope)
        let tokens = TokenStore(scope: scope, prefix: "answers-")
        do {
            let me = try await ZoneChangeReader.currentUserRecordName(in: container)
            let changes = try await ZoneChangeReader.changedZones(in: database, tokens: tokens)
            var answers: [AnswerAlertContent.Answer] = []
            for zoneID in changes.modified {
                answers += try await ZoneChangeReader.changedRecords(in: zoneID, of: database, tokens: tokens, desiredKeys: AnswerAlertContent.desiredKeys)
                    .compactMap(AnswerAlertContent.answer(from:))
            }
            let known = Set(UserDefaults.standard.stringArray(forKey: answeredKey) ?? [])
            let answered = AnswerAlertContent.answeredDays(answers, me: me, known: known)
            // Day keys sort by date ("2026-10-19").
            UserDefaults.standard.set(Array(answered.sorted().suffix(keptDays)), forKey: answeredKey)
            if let event = AnswerAlertContent.event(in: answers, me: me, answeredByMe: answered, now: now) {
                return .event(event)
            }
            if !changes.deleted.isEmpty {
                return .spaceEnded
            }
            if scope == .shared, try await ZoneChangeReader.spaceZones(in: database).isEmpty {
                return .spaceEnded
            }
            return .unknown
        } catch {
            log.error("Answer fetch failed: \(error.localizedDescription, privacy: .public)")
            return .unknown
        }
    }
}
