//
//  AppEnvironment.swift
//  AppCasal
//

import Foundation
import Observation

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
        await reminderNotifications.sync(schedules)
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

    /// Reschedules this device's "Hoje, nós dois" notifications (at most one a day).
    func syncMomentNotifications(now: Date = .now) async {
        guard runMode != .tests, runMode != .preview else { return }
        await reminderNotifications.refreshAuthorization()
        guard let space = spaces.activeSpace(), let me = account.userRecordName else {
            await momentNotifications.sync([], allowed: false)
            return
        }
        let zone = moments.timeZone(of: space)
        let sessions = moments.allSessions(in: space)
        var questions: [String: String] = [:]
        var answered = Set<String>()
        for key in Set(sessions.compactMap(\.dayKey)) {
            guard let session = moments.session(for: key, in: space) else { continue }
            questions[key] = session.questionText
            if moments.state(of: session, for: me)?.mine != nil { answered.insert(key) }
        }
        let memories = (space.memories ?? []).compactMap { memory -> (id: UUID, title: String, date: Date)? in
            guard memory.deletedAt == nil, let id = memory.id, let date = memory.date else { return nil }
            return (id, memory.title ?? "", date)
        }
        let plan = MomentReminderPlanner.plan(.init(
            now: now,
            calendar: .current,
            preferences: momentNotifications.preferences,
            spaceTimeZone: zone,
            questions: questions,
            answered: answered,
            memories: memories
        ))
        await momentNotifications.sync(plan, allowed: reminderNotifications.isAllowed)
    }

    /// After a local change in "Hoje, nós dois" (an answer sent): today's reminder is
    /// cancelled on this device. The partner's device updates when the change syncs.
    func momentsDidChange() {
        Task { await syncMomentNotifications() }
    }

    /// Owner's device: gives a question to today and the next days. Runs at launch and
    /// after every sync; does nothing for the participant or when all days have one.
    func prepareMoments(now: Date = .now) {
        guard runMode != .preview, let space = spaces.activeSpace(), let me = account.userRecordName,
              spaces.role(in: space) == .owner, case .success(let catalog) = catalog else { return }
        _ = try? moments.prepareDays(in: space, questions: catalog.questions, catalogVersion: catalog.questionsVersion, by: me, now: now)
    }
}
