//
//  NoteRepository.swift
//  AppCasal
//

import CoreData

/// Writes notes. Only the author edits or deletes a note. Deletion is logical so it
/// can be undone from "Excluídos recentemente".
final class NoteRepository {
    enum NoteError: LocalizedError {
        case emptyText
        case notAuthor

        var errorDescription: String? {
            switch self {
            case .emptyText: String(localized: "Escreva alguma coisa no recadinho.")
            case .notAuthor: String(localized: "Só quem escreveu o recadinho pode alterá-lo.")
            }
        }
    }

    static let maximumLength = 500

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(text: String, to recipientID: String? = nil, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> Note {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw NoteError.emptyText }
        let note = Note(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(note, to: store)
        }
        note.id = UUID()
        note.text = text
        note.authorID = userRecordName
        note.recipientID = recipientID
        note.createdAt = now
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        note.space = space
        try persistence.save()
        return note
    }

    func update(_ note: Note, text: String, by userRecordName: String, now: Date = .now) throws {
        guard note.authorID == userRecordName else { throw NoteError.notAuthor }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw NoteError.emptyText }
        note.text = text
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }

    func softDelete(_ note: Note, by userRecordName: String, now: Date = .now) throws {
        guard note.authorID == userRecordName else { throw NoteError.notAuthor }
        note.deletedAt = now
        note.deletedBy = userRecordName
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ note: Note, by userRecordName: String, now: Date = .now) throws {
        guard note.authorID == userRecordName else { throw NoteError.notAuthor }
        note.deletedAt = nil
        note.deletedBy = nil
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }
}
