//
//  MomentNotificationTests.swift
//  AppCasalTests
//

import Foundation
import Testing
@testable import AppCasal

struct MomentNotificationTests {
    private let zone = TimeZone(identifier: "America/Sao_Paulo")!
    private var calendar: Calendar { MomentsCalendar.calendar(in: zone) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)))
    }

    private func inputs(now: Date, preferences: MomentNotificationPreferences, questions: [String: String] = [:], answered: Set<String> = [], memories: [(id: UUID, title: String, date: Date)] = [], days: Int = MomentReminderPlanner.minimumDays, calendar: Calendar? = nil) -> MomentReminderPlanner.Inputs {
        .init(now: now, calendar: calendar ?? self.calendar, preferences: preferences, spaceTimeZone: zone, questions: questions, answered: answered, memories: memories, days: days)
    }

    @Test func nothingIsPlannedWithEverythingOff() throws {
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = false
        #expect(MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 9), preferences: preferences)).isEmpty)
    }

    @Test func newQuestionIsOnByDefaultInTheMorning() {
        let preferences = MomentNotificationPreferences()
        #expect(preferences.dailyQuestion)
        #expect(preferences.minutes == 9 * 60)
        #expect(!preferences.weeklyIdea && !preferences.memoryAnniversaries)
    }

    @Test func oneReminderPerDayWithinTheWindowSkippingAnsweredDays() throws {
        var preferences = MomentNotificationPreferences()
        preferences.minutes = 20 * 60
        let now = try date(2026, 10, 18, 9)
        let plan = MomentReminderPlanner.plan(inputs(
            now: now,
            preferences: preferences,
            questions: ["2026-10-19": "Qual música lembra nós dois?"],
            answered: ["2026-10-18"]
        ))
        #expect(plan.count == MomentReminderPlanner.minimumDays - 1)
        #expect(Set(plan.map { $0.components.day }).count == plan.count)
        #expect(plan.allSatisfy { $0.components.hour == 20 && $0.components.minute == 0 })
        // Specific text only for the day whose question is on this device.
        #expect(plan.first?.body.contains("Qual música lembra nós dois?") == true)
        #expect(plan.first?.route == "daily:2026-10-19")
        #expect(plan.dropFirst().allSatisfy { !$0.body.contains("Qual música") })
    }

    @Test func todayIsSkippedOnceTheTimeHasPassed() throws {
        var preferences = MomentNotificationPreferences()
        preferences.minutes = 20 * 60
        let plan = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 21), preferences: preferences))
        #expect(plan.first?.components.day == 19)
    }

    @Test func questionWinsOverAnniversaryAndWeeklyIdeaOnTheSameDay() throws {
        var preferences = MomentNotificationPreferences()
        preferences.minutes = 20 * 60
        preferences.memoryAnniversaries = true
        preferences.weeklyIdea = true
        preferences.weekday = 1 // Sunday
        let memory = (id: UUID(), title: "Piquenique", date: try date(2025, 10, 18))
        let now = try date(2026, 10, 18, 9) // a Sunday
        let all = MomentReminderPlanner.plan(inputs(now: now, preferences: preferences, memories: [memory]))
        #expect(all.first?.kind == .dailyQuestion)
        #expect(all.count == MomentReminderPlanner.minimumDays)

        // Answered today: the anniversary takes the day, never both.
        let answered = MomentReminderPlanner.plan(inputs(now: now, preferences: preferences, answered: ["2026-10-18"], memories: [memory]))
        #expect(answered.first?.kind == .memoryAnniversary)
        #expect(answered.first?.route == MomentsRoute.memory(memory.id).payload)
        #expect(answered.filter { $0.components.day == 18 }.count == 1)
    }

    @Test func memoryFromThisYearIsNotAnAnniversary() throws {
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = false
        preferences.memoryAnniversaries = true
        let memory = (id: UUID(), title: "Hoje", date: try date(2026, 10, 18))
        #expect(MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 9), preferences: preferences, memories: [memory])).isEmpty)
    }

    @Test func routesRoundTripThroughPayloads() {
        let id = UUID()
        let routes: [MomentsRoute] = [.explore, .daily(dayKey: "2026-10-18"), .history, .dates, .ideas, .plans, .gesture, .revive, .game, .memory(id)]
        for route in routes {
            #expect(MomentsRoute(payload: route.payload) == route)
        }
        #expect(MomentsRoute(payload: "memory:not-a-uuid") == nil)
        #expect(MomentsRoute(payload: "unknown") == nil)
        #expect(MomentNotifications.route(from: [MomentNotifications.routeKey: "dates"]) == .dates)
        #expect(MomentNotifications.route(from: ["aps": [:]]) == nil)
    }

    @Test func preferencesPersistOnThisDevice() throws {
        let suite = "MomentPrefs-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = MomentNotifications(defaults: defaults)
        #expect(notifications.preferences.dailyQuestion)
        notifications.preferences.dailyQuestion = false
        notifications.preferences.minutes = 8 * 60 + 30
        let reloaded = MomentNotifications(defaults: defaults)
        #expect(!reloaded.preferences.dailyQuestion)
        #expect(reloaded.preferences.minutes == 510)
    }

    // MARK: Long horizon, idempotent sync, obsolete alerts

    @Test func oldUserWithRemindersOffStaysOff() throws {
        let suite = "MomentPrefs-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "moments.notify.daily")
        defaults.set(20 * 60, forKey: "moments.notify.minutes")
        let notifications = MomentNotifications(defaults: defaults)
        #expect(!notifications.preferences.dailyQuestion)
        #expect(notifications.preferences.minutes == 20 * 60)
    }

    @Test func chosenTimeIsUsedEveryDay() throws {
        var preferences = MomentNotificationPreferences()
        preferences.minutes = 7 * 60 + 15
        let plan = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 6), preferences: preferences))
        #expect(plan.count == MomentReminderPlanner.minimumDays)
        #expect(plan.allSatisfy { $0.components.hour == 7 && $0.components.minute == 15 })
    }

    @Test func turningOffClearsAndTurningOnSchedulesAgain() throws {
        let now = try date(2026, 10, 18, 6)
        let on = MomentReminderPlanner.plan(inputs(now: now, preferences: .init()))
        let existing = Dictionary(uniqueKeysWithValues: on.map { ($0.identifier, $0.signature) })
        var off = MomentNotificationPreferences()
        off.dailyQuestion = false
        let cleared = MomentNotifications.changes(existing: existing, desired: MomentReminderPlanner.plan(inputs(now: now, preferences: off)))
        #expect(cleared.add.isEmpty && cleared.remove.count == on.count)
        let again = MomentNotifications.changes(existing: [:], desired: on)
        #expect(again.add.count == on.count && again.remove.isEmpty)
    }

    @Test func answeringBeforeTheTimeCancelsOnlyThatDay() throws {
        let now = try date(2026, 10, 18, 8)
        let before = MomentReminderPlanner.plan(inputs(now: now, preferences: .init()))
        let after = MomentReminderPlanner.plan(inputs(now: now, preferences: .init(), answered: ["2026-10-18"]))
        let existing = Dictionary(uniqueKeysWithValues: before.map { ($0.identifier, $0.signature) })
        let changes = MomentNotifications.changes(existing: existing, desired: after)
        #expect(changes.remove == ["moments-2026-10-18"])
        #expect(changes.add.isEmpty, "the other days stay scheduled as they are")
    }

    @Test func answeringAfterTheTimeClearsTheDeliveredReminder() throws {
        let plan = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 8), preferences: .init()))
        let today = try #require(plan.first)
        #expect(today.obsoleteWhenAnswered == "2026-10-18")
        let delivered: [(identifier: String, userInfo: [AnyHashable: Any])] = [
            (today.identifier, [MomentNotifications.routeKey: today.route, MomentNotifications.obsoleteDayKey: "2026-10-18"]),
            ("both-answered", [MomentNotifications.routeKey: "daily:2026-10-18"]),
            ("quiz-turn", [MomentNotifications.obsoleteRoundKey: "ABC"]),
        ]
        let obsolete = MomentNotifications.obsolete(delivered, answeredDays: ["2026-10-18"], playedRounds: ["abc"])
        #expect(obsolete == [today.identifier, "quiz-turn"], "news such as both answered stays")
        #expect(MomentNotifications.isObsolete(delivered[0].userInfo, answeredDays: ["2026-10-18"], playedRounds: []))
        #expect(!MomentNotifications.isObsolete(delivered[0].userInfo, answeredDays: [], playedRounds: []))
    }

    @Test func horizonUsesTheRoomLeftByOtherReminders() {
        #expect(MomentReminderPlanner.horizon(otherPending: 0) == 60)
        #expect(MomentReminderPlanner.horizon(otherPending: 10) == 53)
        #expect(MomentReminderPlanner.horizon(otherPending: ReminderNotifications.maximumPending) == 7)
        #expect(MomentReminderPlanner.horizon(otherPending: ReminderNotifications.maximumPending) + ReminderNotifications.maximumPending < MomentReminderPlanner.systemLimit)
    }

    @Test func remindersKeepComingForWeeksWithoutOpeningTheApp() throws {
        let now = try date(2026, 10, 18, 6)
        let plan = MomentReminderPlanner.plan(inputs(now: now, preferences: .init(), questions: ["2026-10-18": "Qual música?"], days: MomentReminderPlanner.horizon(otherPending: 3)))
        #expect(plan.count == 60)
        let last = try #require(plan.last)
        // 30 and more days ahead, at 09:00, with the generic text where no question exists yet.
        #expect(last.components.month == 12 && last.components.day == 16 && last.components.hour == 9)
        #expect(last.body == "A pergunta de hoje está esperando por vocês.")
        #expect(plan.first?.body.contains("Qual música?") == true)
        #expect(Set(plan.map(\.identifier)).count == plan.count, "one request per day, never two")
    }

    @Test func dstDayKeepsTheChosenWallClockTime() throws {
        // Brazil's DST used to start at midnight (2018-11-04 00:00 became 01:00).
        let dstCalendar = MomentsCalendar.calendar(in: zone)
        let now = try #require(dstCalendar.date(from: DateComponents(year: 2018, month: 11, day: 2, hour: 6)))
        let plan = MomentReminderPlanner.plan(inputs(now: now, preferences: .init(), calendar: dstCalendar))
        #expect(plan.allSatisfy { $0.components.hour == 9 && $0.components.minute == 0 })
        let dstDay = try #require(plan.first { $0.components.day == 4 })
        let fire = try #require(dstCalendar.date(from: dstDay.components))
        #expect(dstCalendar.component(.hour, from: fire) == 9)
    }

    @Test func otherDeviceTimeZoneMapsToTheSpaceDay() throws {
        // A trip to Tokyo: 09:00 there is still the previous day in São Paulo.
        let tokyo = MomentsCalendar.calendar(in: try #require(TimeZone(identifier: "Asia/Tokyo")))
        let now = try #require(tokyo.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 6)))
        let plan = MomentReminderPlanner.plan(inputs(now: now, preferences: .init(), questions: ["2026-10-18": "Pergunta de ontem em SP"], calendar: tokyo))
        let first = try #require(plan.first)
        #expect(first.components.day == 19 && first.components.hour == 9)
        #expect(first.route == "daily:2026-10-18")
        #expect(first.body.contains("Pergunta de ontem em SP"))
    }

    @Test func syncIsIdempotent() throws {
        let plan = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 6), preferences: .init()))
        let existing = Dictionary(uniqueKeysWithValues: plan.map { ($0.identifier, $0.signature) })
        let unchanged = MomentNotifications.changes(existing: existing, desired: plan)
        #expect(unchanged.add.isEmpty && unchanged.remove.isEmpty)
        // The question of one day arrived: only that day is replaced.
        let withText = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 6), preferences: .init(), questions: ["2026-10-20": "Nova"]))
        let replaced = MomentNotifications.changes(existing: existing, desired: withText)
        #expect(replaced.remove == ["moments-2026-10-20"] && replaced.add.map(\.identifier) == ["moments-2026-10-20"])
    }
}
