//
//  GoalStep.swift
//  AppCasal
//

import CoreData

/// One step of a goal. Separate record so both partners can tick steps without
/// overwriting each other.
@objc(GoalStep)
nonisolated final class GoalStep: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var sortIndex: Int64
    @NSManaged var doneAt: Date?
    @NSManaged var doneBy: String?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var goal: Goal?
}

// `id` is set on insert by the repositories.
nonisolated extension GoalStep: Identifiable {}

nonisolated extension GoalStep {
    @nonobjc class func fetchRequest() -> NSFetchRequest<GoalStep> {
        NSFetchRequest<GoalStep>(entityName: "GoalStep")
    }
}
