//
//  NoteRepository.swift
//  AppCasal
//

import CoreData

/// Writes notes. Deletion is logical so it can be undone from "Excluídos recentemente".
final class NoteRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(text: String, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> Note {
        let note = Note(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(note, to: store)
        }
        note.id = UUID()
        note.text = text
        note.authorID = userRecordName
        note.createdAt = now
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        note.space = space
        try persistence.save()
        return note
    }

    func update(_ note: Note, text: String, by userRecordName: String, now: Date = .now) throws {
        note.text = text
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }

    func softDelete(_ note: Note, by userRecordName: String, now: Date = .now) throws {
        note.deletedAt = now
        note.deletedBy = userRecordName
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ note: Note, by userRecordName: String, now: Date = .now) throws {
        note.deletedAt = nil
        note.deletedBy = nil
        note.modifiedAt = now
        note.modifiedBy = userRecordName
        try persistence.save()
    }
}
