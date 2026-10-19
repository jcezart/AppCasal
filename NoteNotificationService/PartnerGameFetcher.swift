//
//  PartnerGameFetcher.swift
//  NoteNotificationService
//

import CloudKit
import Foundation
import OSLog

/// Fetches the "Quem conhece melhor?" answers changed since the last game push, with
/// change tokens of its own (prefix `games-`). Remembers which rounds this person
/// played, since the change feed brings each answer only once.
enum PartnerGameFetcher {
    private static let log = Logger(subsystem: "jc.app.dev.AppCasal.NoteNotificationService", category: "games")
    private static let playedKey = "games-playedRounds"
    private static let keptRounds = 40

    static func outcome(in scope: CKDatabase.Scope, now: Date = .now) async -> GameAlertOutcome {
        let container = CKContainer(identifier: NoteAlertContent.containerIdentifier)
        let database = container.database(with: scope)
        let tokens = TokenStore(scope: scope, prefix: "games-")
        do {
            let me = try await ZoneChangeReader.currentUserRecordName(in: container)
            let changes = try await ZoneChangeReader.changedZones(in: database, tokens: tokens)
            var answers: [GameAlertContent.Answer] = []
            for zoneID in changes.modified {
                answers += try await ZoneChangeReader.changedRecords(in: zoneID, of: database, tokens: tokens, desiredKeys: GameAlertContent.desiredKeys)
                    .compactMap(GameAlertContent.answer(from:))
            }
            let known = UserDefaults.standard.stringArray(forKey: playedKey) ?? []
            let played = GameAlertContent.playedRounds(answers, me: me, known: Set(known))
            // Newest last, so the oldest rounds are the ones dropped.
            let ordered = known.filter(played.contains) + answers.filter { $0.authorID == me && !known.contains($0.roundID) }.map(\.roundID)
            UserDefaults.standard.set(Array(ordered.suffix(keptRounds)), forKey: playedKey)
            if let event = GameAlertContent.event(in: answers, me: me, playedByMe: played, now: now) {
                return .event(event)
            }
            if !changes.deleted.isEmpty {
                return .spaceEnded
            }
            if scope == .shared, try await ZoneChangeReader.spaceZones(in: database).isEmpty {
                return .spaceEnded
            }
            return .irrelevant
        } catch {
            log.error("Game fetch failed: \(error.localizedDescription, privacy: .public)")
            return .unknown
        }
    }
}
