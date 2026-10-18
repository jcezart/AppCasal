//
//  PlaceRepository.swift
//  AppCasal
//

import CoreData
import CoreLocation

/// Values for a new place, usually from a map search result.
nonisolated struct PlaceDraft: Equatable, Sendable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var category = MemoryCategory.other
    var status = PlaceStatus.wishlist
    var note = ""
}

/// Writes places. Deletion is logical.
final class PlaceRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(_ draft: PlaceDraft, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> Place {
        let place = Place(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(place, to: store)
        }
        place.id = UUID()
        place.createdAt = now
        place.createdBy = userRecordName
        place.space = space
        place.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        place.address = draft.address
        place.latitude = draft.latitude
        place.longitude = draft.longitude
        apply(category: draft.category, status: draft.status, note: draft.note, to: place, by: userRecordName, now: now)
        try persistence.save()
        return place
    }

    func update(_ place: Place, category: MemoryCategory, status: PlaceStatus, note: String, by userRecordName: String, now: Date = .now) throws {
        apply(category: category, status: status, note: note, to: place, by: userRecordName, now: now)
        try persistence.save()
    }

    /// Marks the place visited, optionally linking the memory registered for the visit.
    func markVisited(_ place: Place, memoryID: UUID?, on date: Date, by userRecordName: String, now: Date = .now) throws {
        place.status = PlaceStatus.visited.rawValue
        place.visitedAt = date
        if let memoryID {
            place.memoryID = memoryID
        }
        place.modifiedAt = now
        place.modifiedBy = userRecordName
        try persistence.save()
    }

    func softDelete(_ place: Place, by userRecordName: String, now: Date = .now) throws {
        place.deletedAt = now
        place.deletedBy = userRecordName
        place.modifiedAt = now
        place.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ place: Place, by userRecordName: String, now: Date = .now) throws {
        place.deletedAt = nil
        place.deletedBy = nil
        place.modifiedAt = now
        place.modifiedBy = userRecordName
        try persistence.save()
    }

    func place(withID id: UUID, in space: CoupleSpace) -> Place? {
        space.places?.first { $0.id == id && $0.deletedAt == nil }
    }

    private func apply(category: MemoryCategory, status: PlaceStatus, note: String, to place: Place, by userRecordName: String, now: Date) {
        place.category = category.rawValue
        if place.status != status.rawValue {
            place.status = status.rawValue
            place.visitedAt = status == .visited ? (place.visitedAt ?? now) : nil
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        place.note = trimmed.isEmpty ? nil : trimmed
        place.modifiedAt = now
        place.modifiedBy = userRecordName
    }
}
