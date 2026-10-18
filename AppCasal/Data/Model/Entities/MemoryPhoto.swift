//
//  MemoryPhoto.swift
//  AppCasal
//

import CoreData

/// One photo of a memory. Separate record per photo so partners adding photos at the
/// same time do not overwrite each other. Binary attributes use external storage,
/// which CloudKit mirroring sends as assets.
@objc(MemoryPhoto)
nonisolated final class MemoryPhoto: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var imageData: Data?
    @NSManaged var thumbnailData: Data?
    @NSManaged var pixelWidth: Double
    @NSManaged var pixelHeight: Double
    @NSManaged var sortIndex: Int64
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var memory: Memory?
}

// `id` is set on insert by the repositories.
nonisolated extension MemoryPhoto: Identifiable {}

nonisolated extension MemoryPhoto {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MemoryPhoto> {
        NSFetchRequest<MemoryPhoto>(entityName: "MemoryPhoto")
    }
}
