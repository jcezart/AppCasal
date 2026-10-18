//
//  Memory.swift
//  AppCasal
//

import CoreData

/// A shared moment: title, description, date, category and photos. Deletion is logical.
@objc(Memory)
nonisolated final class Memory: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var details: String?
    @NSManaged var date: Date?
    /// Raw value of `MemoryCategory`.
    @NSManaged var category: String?
    /// Saved place this memory happened at, if any (by ID; no cross-record reference).
    @NSManaged var placeID: UUID?
    @NSManaged var locationName: String?
    @NSManaged var latitude: NSNumber?
    @NSManaged var longitude: NSNumber?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var photos: Set<MemoryPhoto>?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Memory: Identifiable {}

nonisolated extension Memory {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Memory> {
        NSFetchRequest<Memory>(entityName: "Memory")
    }

    var memoryCategory: MemoryCategory {
        category.flatMap(MemoryCategory.init(rawValue:)) ?? .other
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// Photos not removed, in display order.
    var visiblePhotos: [MemoryPhoto] {
        (photos ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
}
