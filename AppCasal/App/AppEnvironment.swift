//
//  AppEnvironment.swift
//  AppCasal
//

import Foundation
import Observation

/// App-wide dependency graph, created once at launch.
@Observable
final class AppEnvironment {
    static let shared = AppEnvironment(mode: isRunningTests ? .inMemory : .cloudKit)

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let persistence: PersistenceController
    let account: AccountService
    let spaces: SpaceRepository
    let notes: NoteRepository
    let sharing: ShareService
    let sync: SyncMonitor

    init(mode: PersistenceController.Mode) {
        let persistence = PersistenceController(mode: mode)
        let spaces = SpaceRepository(persistence: persistence)
        self.persistence = persistence
        self.spaces = spaces
        account = AccountService(container: persistence.cloudKitContainer)
        notes = NoteRepository(persistence: persistence)
        sharing = ShareService(persistence: persistence, spaces: spaces)
        sync = SyncMonitor()
    }
}
