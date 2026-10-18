//
//  ReminderTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

struct ReminderTests {
    private let owner = "_owner"

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func schedule(on date: Date, daysBefore: Int, yearly: Bool) -> ReminderSchedule {
        schedule(on: date, daysBefore: daysBefore, repetition: yearly ? .yearly : .none)
    }

    private func schedule(on date: Date, daysBefore: Int, repetition: ReminderSchedule.Repetition) -> ReminderSchedule {
        ReminderSchedule(id: UUID(), title: "Aniversário", date: date, daysBefore: daysBefore, repetition: repetition)
    }

    @Test func yearlyRollsToNextAnniversary() {
        let anniversary = schedule(on: date(2024, 6, 12), daysBefore: 3, yearly: true)
        let now = date(2026, 10, 17)
        #expect(anniversary.nextOccurrence(after: now, calendar: calendar) == calendar.startOfDay(for: date(2027, 6, 12)))

        let trigger = anniversary.triggerComponents(after: now, calendar: calendar)
        #expect(trigger?.repeats == true)
        #expect(trigger?.components.month == 6)
        #expect(trigger?.components.day == 9, "3 days before June 12")
        #expect(trigger?.components.hour == ReminderSchedule.notificationHour)
        #expect(trigger?.components.year == nil, "yearly trigger has no year")
    }

    @Test func yearlyOnTheSameDayCountsAsToday() {
        let anniversary = schedule(on: date(2024, 10, 17), daysBefore: 0, yearly: true)
        #expect(anniversary.daysUntilNext(from: date(2026, 10, 17, hour: 20), calendar: calendar) == 0)
    }

    @Test func daysBeforeCrossesMonthBoundary() {
        let event = schedule(on: date(2027, 3, 2), daysBefore: 5, yearly: true)
        let trigger = event.triggerComponents(after: date(2026, 10, 17), calendar: calendar)
        #expect(trigger?.components.month == 2)
        #expect(trigger?.components.day == 25)
    }

    @Test func oneOffInTheFutureFiresOnceAndPastDoesNot() {
        let trip = schedule(on: date(2026, 12, 20), daysBefore: 2, yearly: false)
        let trigger = trip.triggerComponents(after: date(2026, 10, 17), calendar: calendar)
        #expect(trigger?.repeats == false)
        #expect(trigger?.components.year == 2026)
        #expect(trigger?.components.month == 12)
        #expect(trigger?.components.day == 18)

        let past = schedule(on: date(2026, 1, 5), daysBefore: 0, yearly: false)
        #expect(past.nextOccurrence(after: date(2026, 10, 17), calendar: calendar) == nil)
        #expect(past.triggerComponents(after: date(2026, 10, 17), calendar: calendar) == nil)
    }

    @Test func oneOffWhoseNoticeAlreadyPassedIsSkipped() {
        let soon = schedule(on: date(2026, 10, 18), daysBefore: 5, yearly: false)
        #expect(soon.triggerComponents(after: date(2026, 10, 17), calendar: calendar) == nil)
    }

    @Test func monthlyRollsToNextMonthAndSchedulesSeveral() {
        let monthly = schedule(on: date(2024, 6, 12), daysBefore: 1, repetition: .monthly)
        let now = date(2026, 10, 17)
        #expect(monthly.nextOccurrence(after: now, calendar: calendar) == calendar.startOfDay(for: date(2026, 11, 12)))

        let triggers = monthly.triggers(after: now, calendar: calendar)
        #expect(triggers.count == ReminderSchedule.monthlyLookahead)
        #expect(triggers.allSatisfy { !$0.repeats })
        #expect(triggers.first?.components.month == 11)
        #expect(triggers.first?.components.day == 11, "1 day before November 12")
        #expect(triggers.last?.components.year == 2027)
        #expect(triggers.last?.components.month == 4)
    }

    @Test func monthlyOnDay31FallsOnLastDayOfShorterMonths() {
        let monthly = schedule(on: date(2025, 1, 31), daysBefore: 0, repetition: .monthly)
        let days = monthly.occurrences(after: date(2027, 1, 31, hour: 20), limit: 3, calendar: calendar)
            .map { calendar.dateComponents([.month, .day], from: $0) }
        #expect(days.map(\.month) == [1, 2, 3])
        #expect(days.map(\.day) == [31, 28, 31])
    }

    @Test func monthlyThisMonthWhenDayIsStillAhead() {
        let monthly = schedule(on: date(2024, 6, 25), daysBefore: 0, repetition: .monthly)
        #expect(monthly.daysUntilNext(from: date(2026, 10, 17), calendar: calendar) == 8)
    }

    @Test func legacyReminderWithoutIntervalUsesYearlyFlag() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let reminder = Reminder(context: persistence.viewContext)
        reminder.repeatsYearly = true
        #expect(reminder.repetition == .yearly)
        reminder.repeatsYearly = false
        #expect(reminder.repetition == .none)
        reminder.repetition = .monthly
        #expect(reminder.repeatInterval == "monthly")
        #expect(reminder.repeatsYearly == false)
    }

    @Test func notificationBodyByDaysBefore() {
        #expect(ReminderNotifications.body(daysBefore: 0) == String(localized: "É hoje!"))
        #expect(ReminderNotifications.body(daysBefore: 1) == String(localized: "É amanhã."))
        #expect(ReminderNotifications.body(daysBefore: 7) == String(localized: "Faltam \(7) dias."))
    }

    @Test func repositoryLifecycleAndActiveSchedules() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
        let reminders = ReminderRepository(persistence: persistence)

        #expect(throws: ReminderRepository.ReminderError.self) {
            try reminders.create(ReminderDraft(title: " "), in: space, by: owner)
        }
        let anniversary = try reminders.create(
            ReminderDraft(title: " Namoro ", date: date(2024, 6, 12), daysBefore: 99, notifies: true, repetition: .yearly),
            in: space, by: owner
        )
        try reminders.create(ReminderDraft(title: "Sem aviso", notifies: false), in: space, by: owner)
        #expect(anniversary.title == "Namoro")
        #expect(anniversary.daysBefore == Int64(ReminderSchedule.maximumDaysBefore), "clamped")
        #expect(anniversary.objectID.persistentStore == persistence.privateStore)
        #expect(reminders.activeSchedules(in: space).map(\.title) == ["Namoro"], "only reminders with notification")

        var edit = reminders.draft(for: anniversary)
        edit.daysBefore = 1
        try reminders.update(anniversary, with: edit, by: owner)
        #expect(anniversary.daysBefore == 1)

        try reminders.softDelete(anniversary, by: owner)
        #expect(reminders.activeSchedules(in: space).isEmpty)
        try reminders.restore(anniversary, by: owner)
        #expect(reminders.activeSchedules(in: space).count == 1)
    }
}
