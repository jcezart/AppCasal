//
//  Reminder.swift
//  AppCasal
//

import CoreData

/// A date the couple wants to remember (anniversaries and so on). Shared by both
/// partners; each iPhone schedules its own local notification when `notifies` is on.
@objc(Reminder)
nonisolated final class Reminder: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var date: Date?
    @NSManaged var daysBefore: Int64
    @NSManaged var notifies: Bool
    /// `ReminderSchedule.Repetition` raw value. Nil on reminders saved before monthly
    /// repetition existed; those fall back to `repeatsYearly`, which is still written.
    @NSManaged var repeatInterval: String?
    @NSManaged var repeatsYearly: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension Reminder: Identifiable {}

nonisolated extension Reminder {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Reminder> {
        NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    var repetition: ReminderSchedule.Repetition {
        get {
            repeatInterval.flatMap(ReminderSchedule.Repetition.init(rawValue:)) ?? (repeatsYearly ? .yearly : .none)
        }
        set {
            repeatInterval = newValue.rawValue
            repeatsYearly = newValue == .yearly
        }
    }

    /// Plain values for scheduling, safe to pass across isolation.
    var schedule: ReminderSchedule? {
        guard let id, let date else { return nil }
        return ReminderSchedule(id: id, title: title ?? "", date: date, daysBefore: Int(daysBefore), repetition: repetition)
    }
}
