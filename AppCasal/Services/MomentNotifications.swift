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
    /// Day key whose answer makes this reminder pointless (question reminders only).
    var obsoleteWhenAnswered: String? = nil

    /// One per calendar day: rescheduling the same day replaces it instead of adding one.
    var identifier: String {
        "\(MomentNotifications.identifierPrefix)\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// What a pending request must match to be kept as is.
    var signature: String {
        MomentNotifications.signature(title: title, body: body, route: route, components: components)
    }
}

/// Personal choices, on this iPhone only. The new question of each day is on by default
/// (user's request); the others are opt-in. Nothing fires without the system permission.
nonisolated struct MomentNotificationPreferences: Equatable, Sendable {
    var dailyQuestion = true
    /// Minutes after midnight, local time. Default 09:00, early in the question's day.
    var minutes = 9 * 60
    var weeklyIdea = false
    /// 1 = Sunday … 7 = Saturday (Gregorian). Default Friday.
    var weekday = 6
    var memoryAnniversaries = false

    var isAnyEnabled: Bool { dailyQuestion || weeklyIdea || memoryAnniversaries }
}

/// Plans at most one automatic notification per day for the next days. Texts never
/// include answers; a question's text only when that day's question is already on this
/// device. A day already answered gets no question reminder.
///
/// Each day is its own non-repeating request, so answering cancels only that day. The
/// horizon is as long as the pending limit allows, so reminders keep coming for weeks
/// without opening the app (a repeating trigger cannot skip an answered day, and has no
/// start date to hand over from the dated ones without firing twice).
nonisolated enum MomentReminderPlanner {
    /// iOS keeps at most 64 pending requests per app (reminders, these, nothing else).
    static let systemLimit = 64
    static let minimumDays = 7
    static let maximumDays = 60

    /// Days that fit next to `otherPending` requests of this app, one left spare.
    static func horizon(otherPending: Int) -> Int {
        min(maximumDays, max(minimumDays, systemLimit - 1 - otherPending))
    }

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
        /// How many days to plan, from `horizon(otherPending:)`.
        var days = MomentReminderPlanner.minimumDays
    }

    static func plan(_ inputs: Inputs) -> [MomentReminder] {
        let preferences = inputs.preferences
        guard preferences.isAnyEnabled else { return [] }
        let calendar = inputs.calendar
        let today = calendar.startOfDay(for: inputs.now)
        var result: [MomentReminder] = []
        for offset in 0..<max(inputs.days, 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            // The chosen wall-clock time, even on a day that starts with a DST change.
            let date = calendar.dateComponents([.year, .month, .day], from: day)
            let components = DateComponents(year: date.year, month: date.month, day: date.day, hour: preferences.minutes / 60, minute: preferences.minutes % 60)
            guard let fire = calendar.date(from: components), fire > inputs.now else { continue }
            var candidates: [MomentReminder] = []
            if preferences.dailyQuestion {
                let key = inputs.spaceTimeZone.map { MomentsCalendar.dayKey(for: fire, in: $0) }
                if !(key.map(inputs.answered.contains) ?? false) {
                    let text = key.flatMap { inputs.questions[$0] }
                    candidates.append(MomentReminder(
                        kind: .dailyQuestion,
                        components: components,
                        title: String(localized: "Pergunta nova"),
                        body: text.map { String(localized: "Pergunta de hoje: \($0)") } ?? String(localized: "A pergunta de hoje está esperando por vocês."),
                        route: key.map { MomentsRoute.daily(dayKey: $0).payload } ?? MomentsRoute.explore.payload,
                        obsoleteWhenAnswered: key
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
/// personal preferences. Keeps its own set (`moments-*`) in line with the plan on every
/// sync; never touches reminder or note notifications.
@Observable
final class MomentNotifications {
    nonisolated static let identifierPrefix = "moments-"
    nonisolated static let routeKey = "momentsRoute"
    /// Day key (daily question) or round ID (quiz) whose answer makes an alert pointless:
    /// set on question reminders and on the extension's "waiting for you" alerts.
    nonisolated static let obsoleteDayKey = RemoteAlertPresentation.obsoleteDayKey
    nonisolated static let obsoleteRoundKey = RemoteAlertPresentation.obsoleteRoundKey

    var preferences: MomentNotificationPreferences {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()
    /// Syncs run one after the other, so an older plan never lands after a newer one.
    @ObservationIgnored private var lastSync: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var preferences = MomentNotificationPreferences()
        preferences.dailyQuestion = defaults.object(forKey: "moments.notify.daily") as? Bool ?? true
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

    /// Brings the scheduled set in line with the plan (empty clears it). `plan` gets the
    /// number of other pending requests of the app, to size the horizon, and runs when
    /// this sync's turn comes, so it reads the latest data. Idempotent: unchanged days
    /// stay scheduled, changed days are replaced, the rest removed.
    func sync(allowed: Bool, plan: @escaping (_ otherPending: Int) -> [MomentReminder]) async {
        let previous = lastSync
        let task = Task {
            await previous?.value
            await apply(allowed: allowed, plan: plan)
        }
        lastSync = task
        await task.value
    }

    private func apply(allowed: Bool, plan: (Int) -> [MomentReminder]) async {
        let pending = await center.pendingNotificationRequests()
        let own = pending.filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
        let desired = allowed ? plan(pending.count - own.count) : []
        var existing: [String: String] = [:]
        for request in own {
            let components = (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents ?? DateComponents()
            existing[request.identifier] = Self.signature(
                title: request.content.title,
                body: request.content.body,
                route: request.content.userInfo[Self.routeKey] as? String ?? "",
                components: components
            )
        }
        let changes = Self.changes(existing: existing, desired: desired)
        center.removePendingNotificationRequests(withIdentifiers: changes.remove)
        for reminder in changes.add {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "moments"
            var userInfo: [String: String] = [Self.routeKey: reminder.route]
            userInfo[Self.obsoleteDayKey] = reminder.obsoleteWhenAnswered
            content.userInfo = userInfo
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: reminder.components, repeats: false)
            )
            // A failure (e.g. permission revoked meanwhile) is retried on the next sync.
            try? await center.add(request)
        }
    }

    /// Removes delivered alerts that only asked for something already done here: today's
    /// question reminder or "esperando a sua resposta" once answered, "toque para
    /// responder" once the round was played. News (both answered, results) stays.
    func removeObsoleteDelivered(answeredDays: Set<String>, playedRounds: Set<String>) async {
        let delivered = await center.deliveredNotifications()
        let items = delivered.map { (identifier: $0.request.identifier, userInfo: $0.request.content.userInfo) }
        let obsolete = Self.obsolete(items, answeredDays: answeredDays, playedRounds: playedRounds)
        if !obsolete.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: obsolete)
        }
    }

    nonisolated static func signature(title: String, body: String, route: String, components: DateComponents) -> String {
        let when = [components.year, components.month, components.day, components.hour, components.minute].map { String($0 ?? -1) }.joined(separator: "-")
        return [title, body, route, when].joined(separator: "|")
    }

    /// Pending identifiers to remove and reminders to add so the pending set equals `desired`.
    nonisolated static func changes(existing: [String: String], desired: [MomentReminder]) -> (remove: [String], add: [MomentReminder]) {
        let wanted = Dictionary(desired.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        let remove = existing.filter { identifier, signature in wanted[identifier]?.signature != signature }.map(\.key).sorted()
        let add = wanted.values.filter { existing[$0.identifier] != $0.signature }.sorted { $0.identifier < $1.identifier }
        return (remove, add)
    }

    nonisolated static func obsolete(_ items: [(identifier: String, userInfo: [AnyHashable: Any])], answeredDays: Set<String>, playedRounds: Set<String>) -> [String] {
        items.compactMap { item in
            if let day = item.userInfo[obsoleteDayKey] as? String, answeredDays.contains(day) { return item.identifier }
            if let round = item.userInfo[obsoleteRoundKey] as? String, playedRounds.contains(round.lowercased()) { return item.identifier }
            return nil
        }
    }

    /// True for an alert about to show in the foreground that asks for something done.
    nonisolated static func isObsolete(_ userInfo: [AnyHashable: Any], answeredDays: Set<String>, playedRounds: Set<String>) -> Bool {
        !obsolete([(identifier: "", userInfo: userInfo)], answeredDays: answeredDays, playedRounds: playedRounds).isEmpty
    }

    nonisolated static func route(from userInfo: [AnyHashable: Any]) -> MomentsRoute? {
        (userInfo[routeKey] as? String).flatMap(MomentsRoute.init(payload:))
    }
}
