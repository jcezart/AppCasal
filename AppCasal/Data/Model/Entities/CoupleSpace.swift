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
    @NSManaged var memories: Set<Memory>?
    @NSManaged var goals: Set<Goal>?
    @NSManaged var places: Set<Place>?
    @NSManaged var reminders: Set<Reminder>?
    /// "Hoje, nós dois" (model v2). The calendar day of the daily question is counted in
    /// this time zone for both partners; set by the owner when the first day is prepared.
    @NSManaged var momentsTimeZone: String?
    @NSManaged var dailyQuestions: Set<DailyQuestion>?
    @NSManaged var dailyAnswers: Set<DailyAnswer>?
    @NSManaged var gameRounds: Set<GameRound>?
    @NSManaged var gameAnswers: Set<GameAnswer>?
    @NSManaged var datePlans: Set<DatePlan>?
    @NSManaged var dateIdeas: Set<DateIdea>?
    /// Couple photo shown on Início, downscaled like memory photos.
    @NSManaged var coverPhotoData: Data?
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
