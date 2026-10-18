//
//  MomentsSupport.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Screens of "Hoje, nós dois", pushed on the Início stack. Also the target of the
/// local notifications (`MomentNotifications`).
nonisolated enum MomentsRoute: Hashable, Sendable {
    case explore
    case daily(dayKey: String)
    case history
    case dates
    case ideas
    case plans
    case gesture
    case revive
    case game
    case memory(UUID)

    /// For notification payloads: "daily:2026-10-18", "memory:<uuid>", "dates".
    var payload: String {
        switch self {
        case .explore: "explore"
        case .daily(let dayKey): "daily:\(dayKey)"
        case .history: "history"
        case .dates: "dates"
        case .ideas: "ideas"
        case .plans: "plans"
        case .gesture: "gesture"
        case .revive: "revive"
        case .game: "game"
        case .memory(let id): "memory:\(id.uuidString)"
        }
    }

    init?(payload: String) {
        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "explore": self = .explore
        case "daily" where parts.count == 2: self = .daily(dayKey: parts[1])
        case "history": self = .history
        case "dates": self = .dates
        case "ideas": self = .ideas
        case "plans": self = .plans
        case "gesture": self = .gesture
        case "revive": self = .revive
        case "game": self = .game
        case "memory" where parts.count == 2:
            guard let id = UUID(uuidString: parts[1]) else { return nil }
            self = .memory(id)
        default: return nil
        }
    }
}

/// What every screen of the area needs.
struct MomentsContext {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String

    var repository: MomentsRepository { environment.moments }
    var local: MomentsLocalStore { MomentsLocalStore(spaceID: space.id) }
    var partner: Member? { environment.spaces.partner(of: userRecordName, in: space) }
    var partnerName: String { partner?.displayName ?? String(localized: "Seu par") }
    var isOwner: Bool { environment.spaces.role(in: space) == .owner }

    func name(for authorID: String?) -> String {
        if authorID == userRecordName { return String(localized: "Você") }
        return space.members?.first { $0.userRecordName == authorID }?.displayName ?? String(localized: "Seu par")
    }
}

/// Redraws its content when records of this area (or the members) change in the view
/// context, including changes merged from the partner's device.
struct MomentsObserver<Content: View>: View {
    let context: NSManagedObjectContext
    @ViewBuilder let content: () -> Content

    @State private var revision = 0

    private static var entityNames: Set<String> {
        ["DailyQuestion", "DailyAnswer", "GameRound", "GameAnswer", "DatePlan", "DateIdea", "Member", "CoupleSpace", "Memory", "Place"]
    }

    var body: some View {
        let _ = revision
        content()
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { notification in
                if Self.touchesArea(notification) { revision &+= 1 }
            }
    }

    static func touchesArea(_ notification: Notification) -> Bool {
        let keys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSRefreshedObjectsKey]
        return keys.contains { key in
            (notification.userInfo?[key] as? Set<NSManagedObject>)?.contains { object in
                object.entity.name.map(entityNames.contains) ?? false
            } ?? false
        }
    }
}

/// "Hoje", "Ontem" or the date of a day key, in the space's time zone.
enum MomentsDayText {
    static func text(for dayKey: String?, todayKey: String?, timeZone: TimeZone?) -> String {
        guard let dayKey, let timeZone, let date = MomentsCalendar.date(forDayKey: dayKey, in: timeZone) else { return "" }
        if dayKey == todayKey { return String(localized: "Hoje") }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.timeZone = timeZone
        if let todayKey, let today = MomentsCalendar.date(forDayKey: todayKey, in: timeZone),
           MomentsCalendar.dayKey(for: today.addingTimeInterval(-12 * 3600), in: timeZone) == dayKey {
            return String(localized: "Ontem")
        }
        return date.formatted(style)
    }
}

/// Simple reactions to a discovery, as symbols (no emoji as icons).
enum MomentReaction: String, CaseIterable, Identifiable {
    case heart
    case smile
    case sparkles
    case hug

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .heart: "heart.fill"
        case .smile: "face.smiling"
        case .sparkles: "sparkles"
        case .hug: "hands.and.sparkles"
        }
    }

    var title: String {
        switch self {
        case .heart: String(localized: "Amei")
        case .smile: String(localized: "Me fez sorrir")
        case .sparkles: String(localized: "Que descoberta")
        case .hug: String(localized: "Abraço")
        }
    }
}

/// Small header used by the activity screens: icon, serif title, short line.
struct MomentsHeader: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A navigation row of the Explore list: icon, title, subtitle, chevron.
struct MomentsActivityRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accentText)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
