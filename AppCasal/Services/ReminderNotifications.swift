//
//  ReminderNotifications.swift
//  AppCasal
//

import Foundation
import UserNotifications

/// Schedules local notifications for reminders on this device. Rebuilds the full set
/// on every sync, so edits, deletions and changes made by the partner are reflected.
@Observable
final class ReminderNotifications {
    static let identifierPrefix = "reminder-"
    /// With at least 7 days of `MomentNotifications`, stays under the system limit of 64.
    static let maximumPending = 56

    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// App-wide notification permission; reminders and note alerts both depend on it.
    var isAllowed: Bool { authorization == .authorized || authorization == .provisional || authorization == .ephemeral }
    private let center = UNUserNotificationCenter.current()

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Asks for permission if it was never asked. Returns whether alerts are allowed.
    func requestAuthorization() async -> Bool {
        await refreshAuthorization()
        if authorization == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorization()
        }
        return isAllowed
    }

    /// Replaces all scheduled reminder notifications with `schedules`.
    /// Soonest reminders first, so the pending limit drops the farthest ones.
    func sync(_ schedules: [ReminderSchedule], now: Date = .now) async {
        let schedules = schedules.sorted { ($0.daysUntilNext(from: now) ?? .max) < ($1.daysUntilNext(from: now) ?? .max) }
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        await refreshAuthorization()
        guard isAllowed else { return }
        // iOS keeps at most 64 pending requests per app; leave room for other alerts.
        var budget = Self.maximumPending
        for schedule in schedules {
            for (index, trigger) in schedule.triggers(after: now).enumerated() where budget > 0 {
                budget -= 1
                let content = UNMutableNotificationContent()
                content.title = schedule.title
                content.body = Self.body(daysBefore: schedule.daysBefore)
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "\(Self.identifierPrefix)\(schedule.id.uuidString)-\(index)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: trigger.components, repeats: trigger.repeats)
                )
                try? await center.add(request)
            }
        }
    }

    /// How many requests `sync` would schedule, so other alerts can make room first.
    static func plannedCount(_ schedules: [ReminderSchedule], now: Date = .now) -> Int {
        min(maximumPending, schedules.reduce(0) { $0 + $1.triggers(after: now).count })
    }

    static func body(daysBefore: Int) -> String {
        switch daysBefore {
        case 0: String(localized: "É hoje!")
        case 1: String(localized: "É amanhã.")
        default: String(localized: "Faltam \(daysBefore) dias.")
        }
    }
}
