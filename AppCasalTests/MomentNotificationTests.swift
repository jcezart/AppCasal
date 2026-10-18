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

    private func inputs(now: Date, preferences: MomentNotificationPreferences, questions: [String: String] = [:], answered: Set<String> = [], memories: [(id: UUID, title: String, date: Date)] = []) -> MomentReminderPlanner.Inputs {
        .init(now: now, calendar: calendar, preferences: preferences, spaceTimeZone: zone, questions: questions, answered: answered, memories: memories)
    }

    @Test func nothingIsPlannedWithoutOptIn() throws {
        #expect(MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 9), preferences: .init())).isEmpty)
    }

    @Test func oneReminderPerDayWithinTheWindowSkippingAnsweredDays() throws {
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = true
        let now = try date(2026, 10, 18, 9)
        let plan = MomentReminderPlanner.plan(inputs(
            now: now,
            preferences: preferences,
            questions: ["2026-10-19": "Qual música lembra nós dois?"],
            answered: ["2026-10-18"]
        ))
        #expect(plan.count == MomentReminderPlanner.daysAhead - 1)
        #expect(Set(plan.map { $0.components.day }).count == plan.count)
        #expect(plan.allSatisfy { $0.components.hour == 20 && $0.components.minute == 0 })
        // Specific text only for the day whose question is on this device.
        #expect(plan.first?.body.contains("Qual música lembra nós dois?") == true)
        #expect(plan.first?.route == "daily:2026-10-19")
        #expect(plan.dropFirst().allSatisfy { !$0.body.contains("Qual música") })
    }

    @Test func todayIsSkippedOnceTheTimeHasPassed() throws {
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = true
        let plan = MomentReminderPlanner.plan(inputs(now: try date(2026, 10, 18, 21), preferences: preferences))
        #expect(plan.first?.components.day == 19)
    }

    @Test func questionWinsOverAnniversaryAndWeeklyIdeaOnTheSameDay() throws {
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = true
        preferences.memoryAnniversaries = true
        preferences.weeklyIdea = true
        preferences.weekday = 1 // Sunday
        let memory = (id: UUID(), title: "Piquenique", date: try date(2025, 10, 18))
        let now = try date(2026, 10, 18, 9) // a Sunday
        let all = MomentReminderPlanner.plan(inputs(now: now, preferences: preferences, memories: [memory]))
        #expect(all.first?.kind == .dailyQuestion)
        #expect(all.count == MomentReminderPlanner.daysAhead)

        // Answered today: the anniversary takes the day, never both.
        let answered = MomentReminderPlanner.plan(inputs(now: now, preferences: preferences, answered: ["2026-10-18"], memories: [memory]))
        #expect(answered.first?.kind == .memoryAnniversary)
        #expect(answered.first?.route == MomentsRoute.memory(memory.id).payload)
        #expect(answered.filter { $0.components.day == 18 }.count == 1)
    }

    @Test func memoryFromThisYearIsNotAnAnniversary() throws {
        var preferences = MomentNotificationPreferences()
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
        #expect(!notifications.preferences.isAnyEnabled)
        notifications.preferences.dailyQuestion = true
        notifications.preferences.minutes = 8 * 60 + 30
        let reloaded = MomentNotifications(defaults: defaults)
        #expect(reloaded.preferences.dailyQuestion)
        #expect(reloaded.preferences.minutes == 510)
    }
}
