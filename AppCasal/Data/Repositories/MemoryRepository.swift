//
//  MemoryRepository.swift
//  AppCasal
//

import CoreData

/// Values edited in the memory form.
nonisolated struct MemoryDraft: Equatable, Sendable {
    var title = ""
    var details = ""
    var date = Date.now
    var category = MemoryCategory.special
    var place: PlaceLink?

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedTitle.isEmpty }
}

/// Where a memory happened: a saved place or just a name and coordinate.
nonisolated struct PlaceLink: Equatable, Sendable {
    var placeID: UUID?
    var name: String
    var latitude: Double
    var longitude: Double
}

/// Writes memories and their photos. Deletion is logical for memories and photos.
final class MemoryRepository {
    enum MemoryError: LocalizedError {
        case invalidTitle

        var errorDescription: String? {
            String(localized: "Dê um título para a memória.")
        }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(
        _ draft: MemoryDraft,
        photos: [ProcessedPhoto],
        in space: CoupleSpace,
        by userRecordName: String,
        now: Date = .now
    ) throws -> Memory {
        guard draft.isValid else { throw MemoryError.invalidTitle }
        let memory = Memory(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(memory, to: store)
        }
        memory.id = UUID()
        memory.createdAt = now
        memory.createdBy = userRecordName
        memory.space = space
        apply(draft, to: memory, by: userRecordName, now: now)
        for (index, photo) in photos.enumerated() {
            insertPhoto(photo, at: index, in: memory, by: userRecordName, now: now)
        }
        try persistence.save()
        return memory
    }

    /// Updates fields, removes the photos in `removedPhotos` (logically) and appends `newPhotos`.
    func update(
        _ memory: Memory,
        with draft: MemoryDraft,
        removing removedPhotos: Set<NSManagedObjectID> = [],
        adding newPhotos: [ProcessedPhoto] = [],
        by userRecordName: String,
        now: Date = .now
    ) throws {
        guard draft.isValid else { throw MemoryError.invalidTitle }
        apply(draft, to: memory, by: userRecordName, now: now)
        for photo in memory.visiblePhotos where removedPhotos.contains(photo.objectID) {
            photo.deletedAt = now
            photo.deletedBy = userRecordName
        }
        let nextIndex = (memory.visiblePhotos.last?.sortIndex ?? -1) + 1
        for (offset, photo) in newPhotos.enumerated() {
            insertPhoto(photo, at: Int(nextIndex) + offset, in: memory, by: userRecordName, now: now)
        }
        try persistence.save()
    }

    func softDelete(_ memory: Memory, by userRecordName: String, now: Date = .now) throws {
        memory.deletedAt = now
        memory.deletedBy = userRecordName
        memory.modifiedAt = now
        memory.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ memory: Memory, by userRecordName: String, now: Date = .now) throws {
        memory.deletedAt = nil
        memory.deletedBy = nil
        memory.modifiedAt = now
        memory.modifiedBy = userRecordName
        try persistence.save()
    }

    private func apply(_ draft: MemoryDraft, to memory: Memory, by userRecordName: String, now: Date) {
        memory.title = draft.trimmedTitle
        let details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.details = details.isEmpty ? nil : details
        memory.date = draft.date
        memory.category = draft.category.rawValue
        memory.placeID = draft.place?.placeID
        memory.locationName = draft.place?.name
        memory.latitude = draft.place.map { NSNumber(value: $0.latitude) }
        memory.longitude = draft.place.map { NSNumber(value: $0.longitude) }
        memory.modifiedAt = now
        memory.modifiedBy = userRecordName
    }

    private func insertPhoto(_ photo: ProcessedPhoto, at index: Int, in memory: Memory, by userRecordName: String, now: Date) {
        let record = MemoryPhoto(context: context)
        if let store = memory.objectID.persistentStore {
            context.assign(record, to: store)
        }
        record.id = UUID()
        record.imageData = photo.imageData
        record.thumbnailData = photo.thumbnailData
        record.pixelWidth = Double(photo.pixelWidth)
        record.pixelHeight = Double(photo.pixelHeight)
        record.sortIndex = Int64(index)
        record.createdAt = now
        record.createdBy = userRecordName
        record.memory = memory
    }
}
