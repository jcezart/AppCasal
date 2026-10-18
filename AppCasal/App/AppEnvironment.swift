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
    /// Tab to open next, set when a notification is tapped.
    var pendingTab: AppTab?
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

    /// Keeps the partner-note push subscription in line with permission and preference.
    /// Production only: demo, previews and tests never talk to CloudKit.
    func syncNoteAlerts() async {
        guard runMode == .production, let me = account.userRecordName else { return }
        guard let space = spaces.activeSpace() else {
            // The space was deleted or left: no more note alerts until a new one is shared.
            await noteAlerts.removeEverywhere(container: persistence.cloudKitContainer)
            return
        }
        await reminderNotifications.refreshAuthorization()
        let partner = spaces.partner(of: me, in: space)
        await noteAlerts.update(
            role: spaces.role(in: space),
            partnerName: partner.map { $0.displayName ?? "" },
            allowed: reminderNotifications.isAllowed,
            container: persistence.cloudKitContainer
        )
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

    /// Owner's device: gives a question to today and the next days. Runs at launch and
    /// after every sync; does nothing for the participant or when all days have one.
    func prepareMoments(now: Date = .now) {
        guard runMode != .preview, let space = spaces.activeSpace(), let me = account.userRecordName,
              spaces.role(in: space) == .owner, case .success(let catalog) = catalog else { return }
        _ = try? moments.prepareDays(in: space, questions: catalog.questions, catalogVersion: catalog.questionsVersion, by: me, now: now)
    }
}
