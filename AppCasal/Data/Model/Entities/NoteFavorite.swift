//
//  NoteFavorite.swift
//  AppCasal
//

import CoreData

/// Personal favorite of a note. Lives in the private store's default zone, with no
/// relationship to shared data, so it is never shared with the partner.
@objc(NoteFavorite)
nonisolated final class NoteFavorite: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var noteID: UUID?
    /// Owner of the favorite, so a device signed into another account ignores it.
    @NSManaged var userRecordName: String?
    @NSManaged var createdAt: Date?
}

nonisolated extension NoteFavorite {
    @nonobjc class func fetchRequest() -> NSFetchRequest<NoteFavorite> {
        NSFetchRequest<NoteFavorite>(entityName: "NoteFavorite")
    }
}
