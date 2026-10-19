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

    static func outcome(in scope: CKDatabase.Scope, now: Date = .now) async -> NoteAlertOutcome {
        let container = CKContainer(identifier: NoteAlertContent.containerIdentifier)
        let database = container.database(with: scope)
        let tokens = TokenStore(scope: scope)
        do {
            let me = try await ZoneChangeReader.currentUserRecordName(in: container)
            let changes = try await ZoneChangeReader.changedZones(in: database, tokens: tokens)
            var notes: [NoteAlertContent.Note] = []
            for zoneID in changes.modified {
                notes += try await ZoneChangeReader.changedRecords(in: zoneID, of: database, tokens: tokens, desiredKeys: NoteAlertContent.desiredKeys)
                    .compactMap(NoteAlertContent.note(from:))
            }
            if let note = NoteAlertContent.latestFromPartner(notes, me: me, now: now) {
                return .note(note)
            }
            // A deleted zone is reported once, with a change token; without one (first
            // push handled here), an empty database means the same thing.
            if !changes.deleted.isEmpty {
                return .spaceEnded
            }
            if scope == .shared, try await ZoneChangeReader.spaceZones(in: database).isEmpty {
                return .spaceEnded
            }
            return .irrelevant
        } catch {
            log.error("Note fetch failed: \(error.localizedDescription, privacy: .public)")
            return .unknown
        }
    }
}

/// Reads what changed in the space zone since the last push, with change tokens of its
/// own per alert kind, so a note push and an answer push never consume each other's
/// changes.
enum ZoneChangeReader {
    /// The participant's shared database holds only the couple space zone.
    static func spaceZones(in database: CKDatabase) async throws -> [CKRecordZone] {
        try await database.allRecordZones().filter { $0.zoneID != CKRecordZone.default().zoneID }
    }

    /// Asked each time, so a different iCloud account on this iPhone is never taken for
    /// the previous one; the last known name only when the lookup fails.
    static func currentUserRecordName(in container: CKContainer) async throws -> String {
        let key = "userRecordName"
        do {
            let name = try await container.userRecordID().recordName
            UserDefaults.standard.set(name, forKey: key)
            return name
        } catch {
            if let cached = UserDefaults.standard.string(forKey: key) { return cached }
            throw error
        }
    }

    static func changedZones(
        in database: CKDatabase,
        tokens: TokenStore
    ) async throws -> (modified: [CKRecordZone.ID], deleted: [CKRecordZone.ID]) {
        var token = tokens.databaseToken
        var modified: [CKRecordZone.ID] = []
        var deleted: [CKRecordZone.ID] = []
        var moreComing = true
        while moreComing {
            let changes = try await database.databaseChanges(since: token)
            modified += changes.modifications.map(\.zoneID)
            deleted += changes.deletions.map(\.zoneID)
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        tokens.databaseToken = token
        for zoneID in deleted {
            tokens.setZoneToken(nil, for: zoneID)
        }
        let isSpaceZone = { (zoneID: CKRecordZone.ID) in zoneID != CKRecordZone.default().zoneID }
        return (modified.filter(isSpaceZone), deleted.filter(isSpaceZone))
    }

    static func changedRecords(
        in zoneID: CKRecordZone.ID,
        of database: CKDatabase,
        tokens: TokenStore,
        desiredKeys: [CKRecord.FieldKey]
    ) async throws -> [CKRecord] {
        var token = tokens.zoneToken(for: zoneID)
        var records: [CKRecord] = []
        var moreComing = true
        while moreComing {
            let changes = try await database.recordZoneChanges(
                inZoneWith: zoneID,
                since: token,
                desiredKeys: desiredKeys
            )
            for case .success(let modification) in changes.modificationResultsByID.values {
                records.append(modification.record)
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        tokens.setZoneToken(token, for: zoneID)
        return records
    }
}

/// Server change tokens, archived in this extension's own defaults. Notes keep the
/// original keys (empty prefix); each other alert kind has its own prefix.
struct TokenStore {
    let scope: CKDatabase.Scope
    let prefix: String
    private let defaults = UserDefaults.standard

    init(scope: CKDatabase.Scope, prefix: String = "") {
        self.scope = scope
        self.prefix = prefix
    }

    var databaseToken: CKServerChangeToken? {
        get { token(forKey: "\(prefix)db-\(scope.rawValue)") }
        nonmutating set { set(newValue, forKey: "\(prefix)db-\(scope.rawValue)") }
    }

    func zoneToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        token(forKey: zoneKey(zoneID))
    }

    func setZoneToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        set(token, forKey: zoneKey(zoneID))
    }

    private func zoneKey(_ zoneID: CKRecordZone.ID) -> String {
        "\(prefix)zone-\(scope.rawValue)-\(zoneID.ownerName)-\(zoneID.zoneName)"
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
