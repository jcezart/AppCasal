//
//  ReminderSchedule.swift
//  AppCasal
//

import Foundation

/// When a reminder fires. Pure date math, unit tested.
nonisolated struct ReminderSchedule: Equatable, Sendable {
    /// How often the remembered date comes back.
    enum Repetition: String, CaseIterable, Sendable {
        case none
        case monthly
        case yearly
    }

    let id: UUID
    let title: String
    let date: Date
    let daysBefore: Int
    let repetition: Repetition

    /// Local time of day for reminder notifications.
    static let notificationHour = 9
    static let maximumDaysBefore = 60
    /// Monthly notices stay within the month before the event.
    static let maximumDaysBeforeMonthly = 27

    static func maximumDaysBefore(for repetition: Repetition) -> Int {
        repetition == .monthly ? maximumDaysBeforeMonthly : maximumDaysBefore
    }
    /// Monthly reminders are scheduled as this many one-off notifications, renewed on
    /// every sync (launch and data changes). A repeating trigger cannot express
    /// "N days before day 31" in shorter months.
    static let monthlyLookahead = 6

    /// Next date of the event on or after the start of `now`'s day. Repeating events
    /// roll forward; one-off events return nil once past.
    func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date? {
        occurrences(after: now, limit: 1, calendar: calendar).first
    }

    /// Upcoming event days, soonest first. Monthly events on days a month lacks
    /// (29 to 31) fall on that month's last day.
    func occurrences(after now: Date, limit: Int, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let eventDay = calendar.startOfDay(for: date)
        switch repetition {
        case .none:
            return eventDay >= today ? [eventDay] : []
        case .yearly:
            let parts = calendar.dateComponents([.month, .day], from: eventDay)
            var results: [Date] = []
            var cursor = today.addingTimeInterval(-1)
            while results.count < limit,
                  let next = calendar.nextDate(after: cursor, matching: parts, matchingPolicy: .nextTimePreservingSmallerComponents) {
                results.append(next)
                cursor = next
            }
            return results
        case .monthly:
            let day = calendar.component(.day, from: eventDay)
            guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return [] }
            var results: [Date] = []
            var offset = 0
            while results.count < limit, offset < limit + 2 {
                defer { offset += 1 }
                guard let month = calendar.date(byAdding: .month, value: offset, to: firstOfMonth),
                      let length = calendar.range(of: .day, in: .month, for: month)?.count,
                      let candidate = calendar.date(byAdding: .day, value: min(day, length) - 1, to: month),
                      candidate >= today else { continue }
                results.append(candidate)
            }
            return results
        }
    }

    /// Notification moment: `daysBefore` days before the next occurrence, at 9:00.
    /// For yearly reminders, only month/day/time are returned so the trigger repeats.
    func triggerComponents(after now: Date, calendar: Calendar = .current) -> (components: DateComponents, repeats: Bool)? {
        triggers(after: now, calendar: calendar).first
    }

    /// Every notification to schedule now: one repeating trigger for yearly reminders,
    /// up to `monthlyLookahead` one-off triggers for monthly ones, one for one-off.
    func triggers(after now: Date, calendar: Calendar = .current) -> [(components: DateComponents, repeats: Bool)] {
        if repetition == .yearly {
            guard let occurrence = nextOccurrence(after: now, calendar: calendar),
                  let notifyDay = calendar.date(byAdding: .day, value: -daysBefore, to: occurrence) else { return [] }
            var components = calendar.dateComponents([.month, .day], from: notifyDay)
            components.hour = Self.notificationHour
            components.minute = 0
            return [(components, true)]
        }
        let limit = repetition == .monthly ? Self.monthlyLookahead + 1 : 1
        return occurrences(after: now, limit: limit, calendar: calendar)
            .compactMap { occurrence -> Date? in
                guard let notifyDay = calendar.date(byAdding: .day, value: -daysBefore, to: occurrence) else { return nil }
                return calendar.date(bySettingHour: Self.notificationHour, minute: 0, second: 0, of: notifyDay)
            }
            .filter { $0 > now }
            .prefix(repetition == .monthly ? Self.monthlyLookahead : 1)
            .map { (calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0), false) }
    }

    /// Whole days from the start of today until the next occurrence.
    func daysUntilNext(from now: Date, calendar: Calendar = .current) -> Int? {
        guard let occurrence = nextOccurrence(after: now, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: occurrence).day
    }
}
