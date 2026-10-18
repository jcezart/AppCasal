//
//  MomentNotifications.swift
//  AppCasal
//

import Foundation
import Observation
import UserNotifications

/// One local notification of "Hoje, nós dois" on one day.
nonisolated struct MomentReminder: Equatable, Sendable {
    enum Kind: Int, Comparable, Sendable {
        // Higher priority first when two fall on the same day.
        case dailyQuestion = 0
        case memoryAnniversary = 1
        case weeklyIdea = 2

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let kind: Kind
    /// Fire date components in the device calendar (year, month, day, hour, minute).
    let components: DateComponents
    let title: String
    let body: String
    /// `MomentsRoute.payload` opened by a tap.
    let route: String
}

/// Personal choices, on this iPhone only. All off by default (opt-in).
nonisolated struct MomentNotificationPreferences: Equatable, Sendable {
    var dailyQuestion = false
    /// Minutes after midnight, local time. Default 20:00.
    var minutes = 20 * 60
    var weeklyIdea = false
    /// 1 = Sunday … 7 = Saturday (Gregorian). Default Friday.
    var weekday = 6
    var memoryAnniversaries = false

    var isAnyEnabled: Bool { dailyQuestion || weeklyIdea || memoryAnniversaries }
}

/// Plans at most one automatic notification per day for the next days. Texts never
/// include answers; a question's text only when that day's question is already on this
/// device. A day already answered gets no question reminder.
nonisolated enum MomentReminderPlanner {
    static let daysAhead = 7

    struct Inputs {
        var now: Date
        /// Device calendar (time zone of the person's iPhone).
        var calendar: Calendar
        var preferences: MomentNotificationPreferences
        /// Space time zone, for the question of each day. Nil: generic texts.
        var spaceTimeZone: TimeZone?
        /// Question text by day key, when prepared and synced.
        var questions: [String: String]
        /// Day keys the current user already answered.
        var answered: Set<String>
        /// Memories eligible for anniversaries.
        var memories: [(id: UUID, title: String, date: Date)]
    }

    static func plan(_ inputs: Inputs) -> [MomentReminder] {
        let preferences = inputs.preferences
        guard preferences.isAnyEnabled else { return [] }
        let calendar = inputs.calendar
        let today = calendar.startOfDay(for: inputs.now)
        var result: [MomentReminder] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: preferences.minutes, to: day),
                  fire > inputs.now else { continue }
            var candidates: [MomentReminder] = []
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            components.calendar = nil
            if preferences.dailyQuestion {
                let key = inputs.spaceTimeZone.map { MomentsCalendar.dayKey(for: fire, in: $0) }
                if !(key.map(inputs.answered.contains) ?? false) {
                    let text = key.flatMap { inputs.questions[$0] }
                    candidates.append(MomentReminder(
                        kind: .dailyQuestion,
                        components: components,
                        title: String(localized: "Hoje, nós dois"),
                        body: text.map { String(localized: "Pergunta de hoje: \($0)") } ?? String(localized: "A pergunta de hoje está esperando por vocês."),
                        route: key.map { MomentsRoute.daily(dayKey: $0).payload } ?? MomentsRoute.explore.payload
                    ))
                }
            }
            if preferences.memoryAnniversaries, let memory = anniversary(on: day, among: inputs.memories, calendar: calendar) {
                let years = (calendar.dateComponents([.year], from: day).year ?? 0) - (calendar.dateComponents([.year], from: memory.date).year ?? 0)
                candidates.append(MomentReminder(
                    kind: .memoryAnniversary,
                    components: components,
                    title: years == 1 ? String(localized: "Há 1 ano") : String(localized: "Há \(years) anos"),
                    body: String(localized: "Lembram de “\(memory.title)”? Que tal reviver esse momento?"),
                    route: MomentsRoute.memory(memory.id).payload
                ))
            }
            if preferences.weeklyIdea, calendar.component(.weekday, from: day) == preferences.weekday {
                candidates.append(MomentReminder(
                    kind: .weeklyIdea,
                    components: components,
                    title: String(localized: "Ideia para esta semana"),
                    body: String(localized: "Que tal escolher um encontro juntos?"),
                    route: MomentsRoute.dates.payload
                ))
            }
            if let chosen = candidates.min(by: { $0.kind < $1.kind }) {
                result.append(chosen)
            }
        }
        return result
    }

    /// Oldest memory whose anniversary is `day`, at least a year before it. A 29 February
    /// memory is remembered on 28 February in common years.
    static func anniversary(on day: Date, among memories: [(id: UUID, title: String, date: Date)], calendar: Calendar) -> (id: UUID, title: String, date: Date)? {
        let candidates = memories.map { ReviveCandidate(id: $0.id, date: $0.date) }
        guard let suggestion = ReviveRules.suggestion(from: candidates, recent: [], today: day, calendar: calendar),
              suggestion.yearsAgo != nil else { return nil }
        return memories.first { $0.id == suggestion.id }
    }
}

/// Schedules the local notifications of "Hoje, nós dois" on this device and keeps the
/// personal preferences. Rebuilds its own set (`moments-*`) on every sync; never touches
/// reminder or note notifications.
@Observable
final class MomentNotifications {
    static let identifierPrefix = "moments-"
    nonisolated static let routeKey = "momentsRoute"

    var preferences: MomentNotificationPreferences {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = defaults.bool(forKey: "moments.notify.daily")
        if let minutes = defaults.object(forKey: "moments.notify.minutes") as? Int { preferences.minutes = minutes }
        preferences.weeklyIdea = defaults.bool(forKey: "moments.notify.weekly")
        preferences.memoryAnniversaries = defaults.bool(forKey: "moments.notify.anniversaries")
        self.preferences = preferences
    }

    private func save() {
        defaults.set(preferences.dailyQuestion, forKey: "moments.notify.daily")
        defaults.set(preferences.minutes, forKey: "moments.notify.minutes")
        defaults.set(preferences.weeklyIdea, forKey: "moments.notify.weekly")
        defaults.set(preferences.memoryAnniversaries, forKey: "moments.notify.anniversaries")
    }

    /// Replaces the scheduled set with `reminders` (empty clears it).
    func sync(_ reminders: [MomentReminder], allowed: Bool) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) })
        guard allowed else { return }
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = [Self.routeKey: reminder.route]
            let components = reminder.components
            let identifier = "\(Self.identifierPrefix)\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    nonisolated static func route(from userInfo: [AnyHashable: Any]) -> MomentsRoute? {
        (userInfo[routeKey] as? String).flatMap(MomentsRoute.init(payload:))
    }
}
