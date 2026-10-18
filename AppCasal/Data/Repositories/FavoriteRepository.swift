//
//  FavoriteRepository.swift
//  AppCasal
//

import CoreData

/// Personal note favorites. Stored only in the private store (default zone), never shared.
final class FavoriteRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    func favoriteNoteIDs(for userRecordName: String) -> Set<UUID> {
        let request = NoteFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "userRecordName == %@", userRecordName)
        let favorites = (try? context.fetch(request)) ?? []
        return Set(favorites.compactMap(\.noteID))
    }

    /// Adds or removes the favorite. Removing a personal favorite is a real deletion:
    /// it is private, not shared content.
    func toggle(noteID: UUID, for userRecordName: String, now: Date = .now) throws {
        let request = NoteFavorite.fetchRequest()
        request.predicate = NSPredicate(format: "noteID == %@ AND userRecordName == %@", noteID as CVarArg, userRecordName)
        let existing = try context.fetch(request)
        if existing.isEmpty {
            let favorite = NoteFavorite(context: context)
            if let store = persistence.privateStore {
                context.assign(favorite, to: store)
            }
            favorite.id = UUID()
            favorite.noteID = noteID
            favorite.userRecordName = userRecordName
            favorite.createdAt = now
        } else {
            existing.forEach(context.delete)
        }
        try persistence.save()
    }
}
