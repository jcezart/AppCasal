//
//  AppEnvironment.swift
//  AppCasal
//

import BackgroundTasks
import CoreData
import Foundation
import Observation
import UIKit

/// App-wide dependency graph, created once at launch.
@Observable
final class AppEnvironment {
    enum RunMode {
        /// Real data, synced with CloudKit.
        case production
        /// DEBUG only, opt-in with the `-AppCasalDemo YES` launch argument: separate
        /// local stores, no CloudKit, fictitious data. Never enabled automatically.
        case demo
        /// DEBUG only, SwiftUI previews: in-memory stores with demo data.
        case preview
        /// Unit tests: in-memory stores.
        case tests
    }

    static let runMode: RunMode = {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .tests
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "AppCasalDemo") {
            return .demo
        }
        #endif
        return .production
    }()

    static let shared = AppEnvironment(runMode: runMode)

    static var isRunningTests: Bool { runMode == .tests }

    let runMode: RunMode
    let persistence: PersistenceController
    let account: AccountService
    let spaces: SpaceRepository
    let notes: NoteRepository
    let memories: MemoryRepository
    let places: PlaceRepository
    let goals: GoalRepository
    let favorites: FavoriteRepository
    let reminders: ReminderRepository
    let sharing: ShareService
    let moments: MomentsRepository
    let sync: SyncMonitor
    let network = NetworkMonitor()
    let location = LocationService()
    let reminderNotifications = ReminderNotifications()
    let noteAlerts = NoteAlerts()
    let answerAlerts = AnswerAlerts()
    let momentNotifications = MomentNotifications()
    /// Tab to open next, set when a notification is tapped.
    var pendingTab: AppTab?
    /// "Hoje, nós dois" screen to open next, set when its notification is tapped.
    var pendingRoute: MomentsRoute?
    /// Set when this person just created the space: the invitation is offered first.
    var offersInvitation = false

    /// Local fictitious data that is never synced.
    var isDemo: Bool { runMode == .demo || runMode == .preview }

    /// Reschedules this device's reminder notifications from the active space.
    func syncReminderNotifications() async {
        guard runMode != .tests, runMode != .preview else { return }
        let schedules = spaces.activeSpace().map(reminders.activeSchedules) ?? []
        // Reminders and "Hoje, nós dois" share the pending limit: make room before
        // adding reminders (iOS may drop requests past 64), then grow into what is left.
        await syncMomentNotifications(reserving: ReminderNotifications.plannedCount(schedules))
        await reminderNotifications.sync(schedules)
        await syncMomentNotifications()
    }

    /// Keeps the push subscriptions (partner notes and partner answers) in line with
    /// permission and preferences. Production only: demo, previews and tests never talk
    /// to CloudKit.
    func syncNoteAlerts() async {
        guard runMode == .production, let me = account.userRecordName else { return }
        guard let space = spaces.activeSpace() else {
            // The space was deleted or left: no more alerts until a new one is shared.
            await noteAlerts.removeEverywhere(container: persistence.cloudKitContainer)
            await answerAlerts.removeEverywhere(container: persistence.cloudKitContainer)
            return
        }
        await reminderNotifications.refreshAuthorization()
        let partner = spaces.partner(of: me, in: space)
        let role = spaces.role(in: space)
        let partnerName = partner.map { $0.displayName ?? "" }
        await noteAlerts.update(role: role, partnerName: partnerName, allowed: reminderNotifications.isAllowed, container: persistence.cloudKitContainer)
        await answerAlerts.update(role: role, partnerName: partnerName, allowed: reminderNotifications.isAllowed, container: persistence.cloudKitContainer)
    }

    init(runMode: RunMode) {
        let persistence: PersistenceController
        let account: AccountService
        switch runMode {
        case .production:
            persistence = PersistenceController(mode: .cloudKit)
            account = AccountService(container: persistence.cloudKitContainer)
        case .demo:
            #if DEBUG
            persistence = PersistenceController(mode: .local(directory: DemoData.storeDirectory))
            account = AccountService(localUserRecordName: DemoData.ownerID)
            #else
            preconditionFailure("Demo mode is only available in DEBUG builds")
            #endif
        case .preview:
            #if DEBUG
            persistence = PersistenceController(mode: .inMemory)
            account = AccountService(localUserRecordName: DemoData.ownerID)
            #else
            preconditionFailure("Preview mode is only available in DEBUG builds")
            #endif
        case .tests:
            persistence = PersistenceController(mode: .inMemory)
            account = AccountService(container: persistence.cloudKitContainer)
        }
        let spaces = SpaceRepository(persistence: persistence)
        self.runMode = runMode
        self.persistence = persistence
        self.account = account
        self.spaces = spaces
        notes = NoteRepository(persistence: persistence)
        memories = MemoryRepository(persistence: persistence)
        places = PlaceRepository(persistence: persistence)
        goals = GoalRepository(persistence: persistence)
        favorites = FavoriteRepository(persistence: persistence)
        reminders = ReminderRepository(persistence: persistence)
        sharing = ShareService(persistence: persistence, spaces: spaces)
        moments = MomentsRepository(persistence: persistence)
        sync = SyncMonitor()
    }

    /// Content of "Hoje, nós dois", read from the bundle on first use (not at launch).
    @ObservationIgnored private(set) lazy var catalog: Result<MomentsCatalog, MomentsCatalog.CatalogError> = {
        do {
            return .success(try MomentsCatalog.load())
        } catch let error as MomentsCatalog.CatalogError {
            return .failure(error)
        } catch {
            return .failure(.unreadable("catalog", String(describing: error)))
        }
    }()

    /// Reschedules this device's "Hoje, nós dois" notifications (at most one a day) and
    /// clears delivered ones that asked for something already done.
    /// `reserving`: requests about to be added by reminders, counted as already pending.
    func syncMomentNotifications(now: Date = .now, reserving: Int = 0) async {
        guard runMode != .tests, runMode != .preview else { return }
        await reminderNotifications.refreshAuthorization()
        guard let space = spaces.activeSpace(), let me = account.userRecordName else {
            await momentNotifications.sync(allowed: false) { _ in [] }
            return
        }
        let done = momentsDone(in: space, by: me)
        await momentNotifications.sync(allowed: reminderNotifications.isAllowed) { [self] otherPending in
            // Read when this sync's turn comes, so the latest answers count.
            guard let space = spaces.activeSpace() else { return [] }
            let zone = moments.timeZone(of: space)
            var questions: [String: String] = [:]
            for key in Set(moments.allSessions(in: space).compactMap(\.dayKey)) {
                questions[key] = moments.session(for: key, in: space)?.questionText
            }
            let memories = (space.memories ?? []).compactMap { memory -> (id: UUID, title: String, date: Date)? in
                guard memory.deletedAt == nil, let id = memory.id, let date = memory.date else { return nil }
                return (id, memory.title ?? "", date)
            }
            return MomentReminderPlanner.plan(.init(
                now: now,
                calendar: .current,
                preferences: momentNotifications.preferences,
                spaceTimeZone: zone,
                questions: questions,
                answered: momentsDone(in: space, by: me).answeredDays,
                memories: memories,
                days: MomentReminderPlanner.horizon(otherPending: max(otherPending, reserving))
            ))
        }
        await momentNotifications.removeObsoleteDelivered(answeredDays: done.answeredDays, playedRounds: done.playedRounds)
    }

    /// Days this person answered and quiz rounds they played (round IDs lowercased).
    func momentsDone(in space: CoupleSpace, by me: String) -> (answeredDays: Set<String>, playedRounds: Set<String>) {
        var answered = Set<String>()
        for key in Set(moments.allSessions(in: space).compactMap(\.dayKey)) {
            if let session = moments.session(for: key, in: space), moments.state(of: session, for: me)?.mine != nil {
                answered.insert(key)
            }
        }
        let played = Set((space.gameAnswers ?? []).filter { $0.authorID == me }.compactMap { $0.roundID?.uuidString.lowercased() })
        return (answered, played)
    }

    /// For an alert about to show while the app is open: true when it only asks for an
    /// answer or a round already sent from this account.
    func isObsoleteMomentAlert(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let space = spaces.activeSpace(), let me = account.userRecordName else { return false }
        let done = momentsDone(in: space, by: me)
        return MomentNotifications.isObsolete(userInfo, answeredDays: done.answeredDays, playedRounds: done.playedRounds)
    }

    /// After a local change in "Hoje, nós dois" (an answer sent): today's reminder is
    /// cancelled on this device. The partner's device updates when the change syncs.
    func momentsDidChange() {
        Task { await syncMomentNotifications() }
    }

    nonisolated static let refreshTaskIdentifier = "jc.app.dev.AppCasal.notifications-refresh"

    /// Asks iOS for a background refresh in about a day, to extend the reminders. Only a
    /// hint: the system decides if and when it runs (rarely for an app left unopened, and
    /// never after a force quit). The reminders already scheduled do not depend on it.
    func scheduleNotificationRefresh() {
        guard runMode == .production else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60 * 60)
        // Fails in the simulator and when Background App Refresh is off; nothing to do then.
        try? BGTaskScheduler.shared.submit(request)
    }

    /// The background refresh: next request first, then the day and the reminders.
    func refreshNotificationsInBackground() async {
        scheduleNotificationRefresh()
        prepareMoments()
        await syncReminderNotifications()
    }

    /// Keeps notifications current without the interface: CloudKit's silent pushes can
    /// wake the app in the background (not after a force quit, and as the system allows),
    /// and the time zone or the day can change while it runs. Started once at launch.
    func observeChangesForNotifications() async {
        // New days for the owner; today's reminder off once answered elsewhere.
        async let remote: Void = resyncMoments(on: .NSPersistentStoreRemoteChange, preparing: true)
        async let timeZone: Void = resyncMoments(on: .NSSystemTimeZoneDidChange, preparing: false)
        async let day: Void = resyncMoments(on: UIApplication.significantTimeChangeNotification, preparing: true)
        _ = await (remote, timeZone, day)
    }

    private func resyncMoments(on name: Notification.Name, preparing: Bool) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            if preparing { prepareMoments() }
            await syncMomentNotifications()
        }
    }

    /// Owner's device: gives a question to today and the next days. Runs at launch and
    /// after every sync; does nothing for the participant or when all days have one.
    func prepareMoments(now: Date = .now) {
        guard runMode != .preview, let space = spaces.activeSpace(), let me = account.userRecordName,
              spaces.role(in: space) == .owner, case .success(let catalog) = catalog else { return }
        _ = try? moments.prepareDays(in: space, questions: catalog.questions, catalogVersion: catalog.questionsVersion, by: me, now: now)
    }
}
