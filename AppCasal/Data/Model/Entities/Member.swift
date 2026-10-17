//
//  Member.swift
//  AppCasal
//

import CoreData

/// One partner inside a `CoupleSpace`. Each user only edits their own member record.
@objc(Member)
nonisolated final class Member: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var userRecordName: String?
    @NSManaged var displayName: String?
    @NSManaged var role: String?
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Member: Identifiable {}

nonisolated extension Member {
    enum Role: String {
        case owner
        case participant
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Member> {
        NSFetchRequest<Member>(entityName: "Member")
    }
}
