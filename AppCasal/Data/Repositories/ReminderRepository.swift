//
//  ReminderRepository.swift
//  AppCasal
//

import CoreData

/// Values edited in the reminder form.
nonisolated struct ReminderDraft: Equatable, Sendable {
    var title = ""
    var date = Date.now
    var daysBefore = 1
    var notifies = true
    var repetition = ReminderSchedule.Repetition.yearly

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedTitle.isEmpty }
}

/// Writes reminders. Deletion is logical.
final class ReminderRepository {
    enum ReminderError: LocalizedError {
        case invalidTitle

        var errorDescription: String? {
            String(localized: "Dê um nome para o lembrete.")
        }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    private var context: NSManagedObjectContext { persistence.viewContext }

    @discardableResult
    func create(_ draft: ReminderDraft, in space: CoupleSpace, by userRecordName: String, now: Date = .now) throws -> Reminder {
        guard draft.isValid else { throw ReminderError.invalidTitle }
        let reminder = Reminder(context: context)
        if let store = space.objectID.persistentStore {
            context.assign(reminder, to: store)
        }
        reminder.id = UUID()
        reminder.createdAt = now
        reminder.createdBy = userRecordName
        reminder.space = space
        apply(draft, to: reminder, by: userRecordName, now: now)
        try persistence.save()
        return reminder
    }

    func update(_ reminder: Reminder, with draft: ReminderDraft, by userRecordName: String, now: Date = .now) throws {
        guard draft.isValid else { throw ReminderError.invalidTitle }
        apply(draft, to: reminder, by: userRecordName, now: now)
        try persistence.save()
    }

    func softDelete(_ reminder: Reminder, by userRecordName: String, now: Date = .now) throws {
        reminder.deletedAt = now
        reminder.deletedBy = userRecordName
        reminder.modifiedAt = now
        reminder.modifiedBy = userRecordName
        try persistence.save()
    }

    func restore(_ reminder: Reminder, by userRecordName: String, now: Date = .now) throws {
        reminder.deletedAt = nil
        reminder.deletedBy = nil
        reminder.modifiedAt = now
        reminder.modifiedBy = userRecordName
        try persistence.save()
    }

    func draft(for reminder: Reminder) -> ReminderDraft {
        ReminderDraft(
            title: reminder.title ?? "",
            date: reminder.date ?? .now,
            daysBefore: Int(reminder.daysBefore),
            notifies: reminder.notifies,
            repetition: reminder.repetition
        )
    }

    /// Reminders to schedule on this device: not deleted, notifications on.
    func activeSchedules(in space: CoupleSpace) -> [ReminderSchedule] {
        (space.reminders ?? [])
            .filter { $0.deletedAt == nil && $0.notifies }
            .compactMap(\.schedule)
    }

    private func apply(_ draft: ReminderDraft, to reminder: Reminder, by userRecordName: String, now: Date) {
        reminder.title = draft.trimmedTitle
        reminder.date = draft.date
        reminder.daysBefore = Int64(min(max(draft.daysBefore, 0), ReminderSchedule.maximumDaysBefore(for: draft.repetition)))
        reminder.notifies = draft.notifies
        reminder.repetition = draft.repetition
        reminder.modifiedAt = now
        reminder.modifiedBy = userRecordName
    }
}
