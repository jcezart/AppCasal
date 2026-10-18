//
//  GoalRepository.swift
//  AppCasal
//

import CoreData

/// Values edited in the goal form.
nonisolated struct GoalDraft: Equatable, Sendable {
    struct Step: Identifiable, Equatable, Sendable {
        /// Existing step ID, or a new one for steps added in the form.
        var id = UUID()
        var title: String
    }

    var title = ""
    var category = GoalCategory.trip
    var dueDate: Date?
    var coverPhotoData: Data?
    var steps: [Step] = []

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedTitle.isEmpty }
}

/// Writes goals and steps. Deletion is logical for goals and steps.
final class GoalRepository {
    enum GoalError: LocalizedError {
        case invalidTitle

        var errorDescription: String? {
            String(localized: "Dê um título para a meta.")
        }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(_ draft: GoalDraft, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> Goal {
        guard draft.isValid else { throw GoalError.invalidTitle }
        let goal = Goal(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(goal, to: store)
        }
        goal.id = UUID()
        goal.createdAt = now
        goal.createdBy = userRecordName
        goal.space = space
        apply(draft, to: goal, by: userRecordName, now: now)
        try persistence.save()
        return goal
    }

    func update(_ goal: Goal, with draft: GoalDraft, by userRecordName: String, now: Date = .now) throws {
        guard draft.isValid else { throw GoalError.invalidTitle }
        apply(draft, to: goal, by: userRecordName, now: now)
        try persistence.save()
    }

    /// Ticks or unticks a step. Only the step record changes.
    func toggle(_ step: GoalStep, by userRecordName: String, now: Date = .now) throws {
        if step.doneAt == nil {
            step.doneAt = now
            step.doneBy = userRecordName
        } else {
            step.doneAt = nil
            step.doneBy = nil
        }
        try persistence.save()
    }

    func complete(_ goal: Goal, by userRecordName: String, now: Date = .now) throws {
        goal.completedAt = now
        goal.completedBy = userRecordName
        goal.modifiedAt = now
        goal.modifiedBy = userRecordName
        try persistence.save()
    }

    func reopen(_ goal: Goal, by userRecordName: String, now: Date = .now) throws {
        goal.completedAt = nil
        goal.completedBy = nil
        goal.modifiedAt = now
        goal.modifiedBy = userRecordName
        try persistence.save()
    }

    func softDelete(_ goal: Goal, by userRecordName: String, now: Date = .now) throws {
        goal.deletedAt = now
        goal.deletedBy = userRecordName
        goal.modifiedAt = now
        goal.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ goal: Goal, by userRecordName: String, now: Date = .now) throws {
        goal.deletedAt = nil
        goal.deletedBy = nil
        goal.modifiedAt = now
        goal.modifiedBy = userRecordName
        try persistence.save()
    }

    /// Draft for editing an existing goal.
    func draft(for goal: Goal) -> GoalDraft {
        GoalDraft(
            title: goal.title ?? "",
            category: goal.goalCategory,
            dueDate: goal.dueDate,
            coverPhotoData: goal.coverPhotoData,
            steps: goal.visibleSteps.map { GoalDraft.Step(id: $0.id ?? UUID(), title: $0.title ?? "") }
        )
    }

    private func apply(_ draft: GoalDraft, to goal: Goal, by userRecordName: String, now: Date) {
        goal.title = draft.trimmedTitle
        goal.category = draft.category.rawValue
        goal.dueDate = draft.dueDate
        if goal.coverPhotoData != draft.coverPhotoData {
            goal.coverPhotoData = draft.coverPhotoData
        }
        goal.modifiedAt = now
        goal.modifiedBy = userRecordName

        // Steps: keep matching IDs (rename, reorder), remove missing ones logically, add new ones.
        let existing = Dictionary((goal.steps ?? []).compactMap { step in step.id.map { ($0, step) } }, uniquingKeysWith: { first, _ in first })
        let wanted = draft.steps.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let wantedIDs = Set(wanted.map(\.id))
        for step in goal.visibleSteps where !wantedIDs.contains(step.id ?? UUID()) {
            step.deletedAt = now
            step.deletedBy = userRecordName
        }
        for (index, item) in wanted.enumerated() {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let step = existing[item.id], step.deletedAt == nil {
                if step.title != title { step.title = title }
                if step.sortIndex != Int64(index) { step.sortIndex = Int64(index) }
            } else {
                let step = GoalStep(context: context)
                if let store = goal.objectID.persistentStore {
                    context.assign(step, to: store)
                }
                step.id = item.id
                step.title = title
                step.sortIndex = Int64(index)
                step.createdAt = now
                step.createdBy = userRecordName
                step.goal = goal
            }
        }
    }
}
