//
//  Place.swift
//  AppCasal
//

import CoreData
import CoreLocation

/// A place the couple visited or wants to visit.
@objc(Place)
nonisolated final class Place: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var address: String?
    /// Raw value of `MemoryCategory` (shared category list).
    @NSManaged var category: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    /// Raw value of `PlaceStatus`.
    @NSManaged var status: String?
    @NSManaged var note: String?
    @NSManaged var visitedAt: Date?
    /// Memory created when the visit was registered.
    @NSManaged var memoryID: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Place: Identifiable {}

nonisolated extension Place {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Place> {
        NSFetchRequest<Place>(entityName: "Place")
    }

    var placeStatus: PlaceStatus {
        status.flatMap(PlaceStatus.init(rawValue:)) ?? .wishlist
    }

    var placeCategory: MemoryCategory {
        category.flatMap(MemoryCategory.init(rawValue:)) ?? .other
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
