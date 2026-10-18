//
//  Goal.swift
//  AppCasal
//

import CoreData

/// A shared plan with optional due date and steps. Progress is derived from the steps,
/// never stored. Completion is explicit (`completedAt`) and kept as history.
@objc(Goal)
nonisolated final class Goal: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    /// Raw value of `GoalCategory`.
    @NSManaged var category: String?
    @NSManaged var dueDate: Date?
    @NSManaged var completedAt: Date?
    @NSManaged var completedBy: String?
    @NSManaged var coverPhotoData: Data?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var steps: Set<GoalStep>?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Goal: Identifiable {}

nonisolated extension Goal {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Goal> {
        NSFetchRequest<Goal>(entityName: "Goal")
    }

    var goalCategory: GoalCategory {
        category.flatMap(GoalCategory.init(rawValue:)) ?? .other
    }

    /// Steps not removed, in display order.
    var visibleSteps: [GoalStep] {
        (steps ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var completedStepCount: Int { visibleSteps.filter { $0.doneAt != nil }.count }

    /// 0...1; a goal without steps counts as done only when completed.
    var progress: Double {
        let steps = visibleSteps
        guard !steps.isEmpty else { return completedAt == nil ? 0 : 1 }
        return Double(completedStepCount) / Double(steps.count)
    }

    var isCompleted: Bool { completedAt != nil }
}
