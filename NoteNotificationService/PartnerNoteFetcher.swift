//
//  PartnerNoteFetcher.swift
//  NoteNotificationService
//

import CloudKit
import Foundation
import OSLog

/// Fetches the notes changed since the last push and returns the partner's latest one. Uses its own change tokens (kept in this extension's defaults),
/// independent from the app's `NSPersistentCloudKitContainer` mirroring.
enum PartnerNoteFetcher {
    private static let log = Logger(subsystem: "jc.app.dev.AppCasal.NoteNotificationService", category: "fetch")

    static func latestNote(in scope: CKDatabase.Scope, now: Date = .now) async -> NoteAlertContent.Note? {
        let container = CKContainer(identifier: NoteAlertContent.containerIdentifier)
        let database = container.database(with: scope)
        let tokens = TokenStore(scope: scope)
        do {
            let me = try await currentUserRecordName(in: container)
            var notes: [NoteAlertContent.Note] = []
            for zoneID in try await changedZones(in: database, tokens: tokens) where zoneID != CKRecordZone.default().zoneID {
                notes += try await changedNotes(in: zoneID, of: database, tokens: tokens)
            }
            return NoteAlertContent.latestFromPartner(notes, me: me, now: now)
        } catch {
            log.error("Note fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func currentUserRecordName(in container: CKContainer) async throws -> String {
        let key = "userRecordName"
        if let cached = UserDefaults.standard.string(forKey: key) {
            return cached
        }
        let name = try await container.userRecordID().recordName
        UserDefaults.standard.set(name, forKey: key)
        return name
    }

    private static func changedZones(in database: CKDatabase, tokens: TokenStore) async throws -> [CKRecordZone.ID] {
        var token = tokens.databaseToken
        var zones: [CKRecordZone.ID] = []
        var moreComing = true
        while moreComing {
            let changes = try await database.databaseChanges(since: token)
            zones += changes.modifications.map(\.zoneID)
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        tokens.databaseToken = token
        return zones
    }

    private static func changedNotes(
        in zoneID: CKRecordZone.ID,
        of database: CKDatabase,
        tokens: TokenStore
    ) async throws -> [NoteAlertContent.Note] {
        var token = tokens.zoneToken(for: zoneID)
        var notes: [NoteAlertContent.Note] = []
        var moreComing = true
        while moreComing {
            let changes = try await database.recordZoneChanges(
                inZoneWith: zoneID,
                since: token,
                desiredKeys: NoteAlertContent.desiredKeys
            )
            for case .success(let modification) in changes.modificationResultsByID.values {
                if let note = NoteAlertContent.note(from: modification.record) {
                    notes.append(note)
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        tokens.setZoneToken(token, for: zoneID)
        return notes
    }
}

/// Server change tokens, archived in this extension's own defaults.
private struct TokenStore {
    let scope: CKDatabase.Scope
    private let defaults = UserDefaults.standard

    var databaseToken: CKServerChangeToken? {
        get { token(forKey: "db-\(scope.rawValue)") }
        nonmutating set { set(newValue, forKey: "db-\(scope.rawValue)") }
    }

    func zoneToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        token(forKey: zoneKey(zoneID))
    }

    func setZoneToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        set(token, forKey: zoneKey(zoneID))
    }

    private func zoneKey(_ zoneID: CKRecordZone.ID) -> String {
        "zone-\(scope.rawValue)-\(zoneID.ownerName)-\(zoneID.zoneName)"
    }

    private func token(forKey key: String) -> CKServerChangeToken? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func set(_ token: CKServerChangeToken?, forKey key: String) {
        guard let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
