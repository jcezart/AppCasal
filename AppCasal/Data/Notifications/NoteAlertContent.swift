//
//  NoteAlertContent.swift
//  AppCasal
//
//  Compiled in the app and in the NoteNotificationService extension.
//

import CloudKit
import Foundation

/// Turns the note records fetched by the notification extension into the alert text.
/// The database subscription push carries no record fields, so the extension fetches
/// the changed notes and shows the partner's latest one.
nonisolated enum NoteAlertContent {
    static let containerIdentifier = "iCloud.jc.app.dev.casal"
    static let subscriptionID = "note-alerts-v1"
    /// Core Data prefixes mirrored record types and fields with `CD_`.
    static let recordType = "CD_Note"
    static let desiredKeys: [CKRecord.FieldKey] = ["CD_text", "CD_authorID", "CD_createdAt", "CD_modifiedAt", "CD_deletedAt"]
    /// Changes older than this are not the reason for the push being handled.
    static let recentWindow: TimeInterval = 15 * 60
    static let maximumBodyLength = 240

    struct Note: Equatable, Sendable {
        var text: String
        var authorID: String
        var createdAt: Date
        var modifiedAt: Date
        var deletedAt: Date?

        /// Saved again after creation (edits, restorations).
        var isEdited: Bool { modifiedAt.timeIntervalSince(createdAt) > 5 }
    }

    static func note(from record: CKRecord) -> Note? {
        guard record.recordType == recordType,
              let text = record["CD_text"] as? String,
              let authorID = record["CD_authorID"] as? String,
              let createdAt = record["CD_createdAt"] as? Date else { return nil }
        return Note(
            text: text,
            authorID: authorID,
            createdAt: createdAt,
            modifiedAt: record["CD_modifiedAt"] as? Date ?? createdAt,
            deletedAt: record["CD_deletedAt"] as? Date
        )
    }

    /// The partner's most recently changed note, if it changed recently and is not deleted.
    static func latestFromPartner(_ notes: [Note], me: String, now: Date) -> Note? {
        notes
            .filter { $0.authorID != me && $0.deletedAt == nil && now.timeIntervalSince($0.modifiedAt) <= recentWindow }
            .max { $0.modifiedAt < $1.modifiedAt }
    }

    static func body(for note: Note) -> String {
        let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = text.count > maximumBodyLength ? String(text.prefix(maximumBodyLength - 1)) + "…" : text
        return note.isEdited ? String(localized: "Editado: \(clipped)") : clipped
    }

    /// When the note was written (or last edited), shown under the alert title.
    static func subtitle(for note: Note, now: Date = .now) -> String {
        NoteTimestamp.text(for: note.isEdited ? note.modifiedAt : note.createdAt, now: now)
    }

    /// Database scope of a push from the note alert subscription; nil for other pushes.
    static func databaseScope(of userInfo: [AnyHashable: Any]) -> CKDatabase.Scope? {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notification.subscriptionID == subscriptionID else { return nil }
        return notification.databaseScope
    }
}
