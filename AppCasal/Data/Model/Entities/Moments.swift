//
//  Moments.swift
//  AppCasal
//
//  Entities of "Hoje, nós dois" (model v2). All live in the couple space zone and
//  carry snapshots of the catalog text, so catalog updates never change past records.
//

import CoreData

/// The question of one calendar day, prepared by the owner for both partners.
/// Two devices of the owner may create the same day while offline; readers pick one
/// deterministically (`MomentsRepository.canonical`).
@objc(DailyQuestion)
nonisolated final class DailyQuestion: NSManagedObject {
    @NSManaged var id: UUID?
    /// "yyyy-MM-dd" in the space's `momentsTimeZone`.
    @NSManaged var dayKey: String?
    @NSManaged var questionID: String?
    @NSManaged var questionText: String?
    @NSManaged var category: String?
    @NSManaged var catalogVersion: String?
    /// Pass through the catalog (0, 1, …); a new cycle starts once every question was used.
    @NSManaged var cycle: Int64
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    /// Memory saved from this discovery ("Guardar como memória"), so it is saved once.
    @NSManaged var memoryID: UUID?
    @NSManaged var space: CoupleSpace?
}

/// One partner's sent answer to a daily question. Written once by its author and never
/// changed afterwards, except the author's own reaction to the discovery.
@objc(DailyAnswer)
nonisolated final class DailyAnswer: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var dayKey: String?
    @NSManaged var questionID: String?
    @NSManaged var questionText: String?
    @NSManaged var text: String?
    @NSManaged var authorID: String?
    @NSManaged var submittedAt: Date?
    @NSManaged var reaction: String?
    @NSManaged var reactedAt: Date?
    @NSManaged var space: CoupleSpace?
}

/// A "Quem conhece melhor?" round: five questions with their options, frozen at creation.
@objc(GameRound)
nonisolated final class GameRound: NSManagedObject {
    @NSManaged var id: UUID?
    /// JSON array of `GameQuestionSnapshot`.
    @NSManaged var questionsJSON: String?
    @NSManaged var catalogVersion: String?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var cancelledAt: Date?
    @NSManaged var space: CoupleSpace?
}

/// One partner's finished choices and guesses for a round. Written once by its author.
@objc(GameAnswer)
nonisolated final class GameAnswer: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var roundID: UUID?
    @NSManaged var authorID: String?
    /// JSON array of `GameEntry`.
    @NSManaged var entriesJSON: String?
    @NSManaged var submittedAt: Date?
    @NSManaged var space: CoupleSpace?
}

/// A date the couple decided to do ("Vamos fazer"), from the catalog, a saved place or
/// one of their own ideas. Optionally an invitation to the partner, answered in place.
@objc(DatePlan)
nonisolated final class DatePlan: NSManagedObject {
    @NSManaged var id: UUID?
    /// Raw value of `DateSource.Kind`.
    @NSManaged var sourceKind: String?
    /// Catalog ID, place UUID or idea UUID.
    @NSManaged var sourceID: String?
    @NSManaged var title: String?
    @NSManaged var details: String?
    /// Raw value of `DateInvitation` (nil: a plan without invitation).
    @NSManaged var invitation: String?
    @NSManaged var invitationChangedAt: Date?
    @NSManaged var invitationChangedBy: String?
    @NSManaged var completedAt: Date?
    @NSManaged var completedBy: String?
    @NSManaged var memoryID: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var createdBy: String?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var space: CoupleSpace?
}

/// A date idea written by one partner. Shared with the couple once saved; only the
/// author edits or deletes it (logically).
@objc(DateIdea)
nonisolated final class DateIdea: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var details: String?
    /// Raw value of `DateLocation`.
    @NSManaged var location: String?
    /// Raw value of `DateCost`.
    @NSManaged var costTier: String?
    /// 0 when not given.
    @NSManaged var durationMinutes: Int64
    @NSManaged var remoteFriendly: Bool
    @NSManaged var authorID: String?
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
    @NSManaged var modifiedBy: String?
    @NSManaged var deletedAt: Date?
    @NSManaged var deletedBy: String?
    @NSManaged var space: CoupleSpace?
}

// `id` is set on insert by the repositories.
nonisolated extension DailyQuestion: Identifiable {}
nonisolated extension DailyAnswer: Identifiable {}
nonisolated extension GameRound: Identifiable {}
nonisolated extension GameAnswer: Identifiable {}
nonisolated extension DatePlan: Identifiable {}
nonisolated extension DateIdea: Identifiable {}

nonisolated extension DailyQuestion {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DailyQuestion> { NSFetchRequest(entityName: "DailyQuestion") }
}

nonisolated extension DailyAnswer {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DailyAnswer> { NSFetchRequest(entityName: "DailyAnswer") }
}

nonisolated extension GameRound {
    @nonobjc class func fetchRequest() -> NSFetchRequest<GameRound> { NSFetchRequest(entityName: "GameRound") }
}

nonisolated extension GameAnswer {
    @nonobjc class func fetchRequest() -> NSFetchRequest<GameAnswer> { NSFetchRequest(entityName: "GameAnswer") }
}

nonisolated extension DatePlan {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DatePlan> { NSFetchRequest(entityName: "DatePlan") }
}

nonisolated extension DateIdea {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DateIdea> { NSFetchRequest(entityName: "DateIdea") }
}
