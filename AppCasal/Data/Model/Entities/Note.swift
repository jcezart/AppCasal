//
//  Note.swift
//  AppCasal
//

import CoreData

/// A short message between partners ("recadinho"). Deletion is logical (`deletedAt`).
@objc(Note)
nonisolated final class Note: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var text: String?
    @NSManaged var authorID: String?
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Note: Identifiable {}

nonisolated extension Note {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Note> {
        NSFetchRequest<Note>(entityName: "Note")
    }
}
