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
    let sharing: ShareService
    let sync: SyncMonitor

    /// Local fictitious data that is never synced.
    var isDemo: Bool { runMode == .demo || runMode == .preview }

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
        sharing = ShareService(persistence: persistence, spaces: spaces)
        sync = SyncMonitor()
    }
}
