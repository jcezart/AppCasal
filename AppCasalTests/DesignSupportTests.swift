//
//  DesignSupportTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import Testing
@testable import AppCasal

struct DesignSupportTests {
    private let owner = "_owner"

    @Test func daysTogetherCountsCalendarDays() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9)))

        #expect(space.daysTogether(now: now, calendar: calendar) == nil)

        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 23)))
        try spaces.setRelationshipStart(start, in: space)
        #expect(space.daysTogether(now: now, calendar: calendar) == 7)

        let future = try #require(calendar.date(byAdding: .day, value: 3, to: now))
        try spaces.setRelationshipStart(future, in: space)
        #expect(space.daysTogether(now: now, calendar: calendar) == nil)
    }

    @Test func partnerIsTheOtherMember() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        #expect(spaces.partner(of: owner, in: space) == nil)

        try spaces.ensureMember(named: "Lucas", userRecordName: "_partner", in: space)
        #expect(spaces.partner(of: owner, in: space)?.displayName == "Lucas")
        #expect(spaces.partner(of: "_partner", in: space)?.displayName == "Ana")
    }

    @Test func syncStateReflectsDemoAndAccount() {
        let monitor = SyncMonitor()
        #expect(monitor.displayState(isDemo: true, accountStatus: .available) == .demo)
        #expect(monitor.displayState(isDemo: false, accountStatus: .noAccount) == .accountUnavailable)
        #expect(monitor.displayState(isDemo: false, accountStatus: .available) == .upToDate)
    }

    #if DEBUG
    @Test func demoStoresAreSeparateFromRealStores() {
        let real = NSPersistentContainer.defaultDirectoryURL().appending(path: "Private.sqlite").standardizedFileURL
        let demo = DemoData.storeDirectory.appending(path: "Private.sqlite").standardizedFileURL
        #expect(real != demo)
        #expect(DemoData.storeDirectory.lastPathComponent == "DemoStores")
    }

    @Test func demoSeedUsesProductionRepositoriesInMemory() throws {
        let environment = AppEnvironment(runMode: .preview)
        try DemoData.seedIfNeeded(environment)
        let space = try #require(environment.spaces.activeSpace())
        #expect(space.members?.count == 2)
        #expect(space.notes?.count == 3)
        #expect(environment.isDemo)

        try DemoData.seedIfNeeded(environment)
        #expect(space.notes?.count == 3, "seeding is idempotent")
    }
    #endif
}
