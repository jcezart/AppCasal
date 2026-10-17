//
//  AccountServiceTests.swift
//  AppCasalTests
//

import CloudKit
import Foundation
import Testing
@testable import AppCasal

struct AccountServiceTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "AccountServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)

    @Test func withoutCacheWaitsForICloud() throws {
        let account = AccountService(container: container, defaults: try makeDefaults())
        #expect(account.status == .checking)
        #expect(account.userRecordName == nil)
    }

    @Test func cachedIdentityOpensImmediately() throws {
        let defaults = try makeDefaults()
        defaults.set("_cached", forKey: AccountService.cachedUserRecordNameKey)
        let account = AccountService(container: container, defaults: defaults)
        #expect(account.status == .available)
        #expect(account.userRecordName == "_cached")
    }
}
