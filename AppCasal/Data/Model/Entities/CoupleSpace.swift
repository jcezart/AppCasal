//
//  CoupleSpace.swift
//  AppCasal
//

import CoreData

/// Root of the couple's shared data. Sharing this object shares everything related to it.
///
/// `nonisolated` because Core Data and CloudKit mirroring create and read managed
/// objects on their own queues; isolation is provided by the owning context.
@objc(CoupleSpace)
nonisolated final class CoupleSpace: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var deletedAt: Date?
    @NSManaged var relationshipStart: Date?
    /// Set when the owner stops sharing. A space whose partnership ended is never shared again:
    /// a new partner starts in a new space and never sees this history.
    @NSManaged var sharingEndedAt: Date?
    @NSManaged var members: Set<Member>?
    @NSManaged var notes: Set<Note>?
}

// `id` is set on insert by the repositories.
nonisolated extension CoupleSpace: Identifiable {}

nonisolated extension CoupleSpace {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CoupleSpace> {
        NSFetchRequest<CoupleSpace>(entityName: "CoupleSpace")
    }
}

nonisolated extension CoupleSpace {
    /// Whole days since `relationshipStart`, counted in calendar days; nil when not set.
    func daysTogether(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let relationshipStart else { return nil }
        let start = calendar.startOfDay(for: relationshipStart)
        let end = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: start, to: end).day, days >= 0 else { return nil }
        return days
    }
}
