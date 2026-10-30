//
//  DesignSupportTests.swift
//  AppCasalTests
//

import CloudKit
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

    @Test func invitationIsPendingUntilThePartnerJoins() throws {
        let environment = AppEnvironment(runMode: .tests)
        let space = try environment.spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        #expect(InvitePartner.isPending(environment, space: space, userRecordName: owner))

        try environment.spaces.ensureMember(named: "Lucas", userRecordName: "_partner", in: space)
        #expect(!InvitePartner.isPending(environment, space: space, userRecordName: owner))

        let ended = try environment.spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        ended.sharingEndedAt = .now
        #expect(!InvitePartner.isPending(environment, space: ended, userRecordName: owner))

        let demo = AppEnvironment(runMode: .preview)
        let demoSpace = try demo.spaces.createSpace(ownerName: "Ana", userRecordName: owner)
        #expect(!InvitePartner.isPending(demo, space: demoSpace, userRecordName: owner))
    }

    @Test func syncStateReflectsDemoAndAccount() {
        let monitor = SyncMonitor()
        #expect(monitor.displayState(isDemo: true, accountStatus: .available) == .demo)
        #expect(monitor.displayState(isDemo: false, accountStatus: .noAccount) == .accountUnavailable)
        #expect(monitor.displayState(isDemo: false, accountStatus: .available) == .upToDate)
        #expect(monitor.displayState(isDemo: false, accountStatus: .available, isConnected: false) == .offline(pending: nil))
    }

    @Test func fullICloudIsRecognizedInsideWrappedErrors() {
        let quota = CKError(.quotaExceeded)
        #expect(SyncMonitor.isQuotaExceeded(quota))
        let partial = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "a"): CKError(.quotaExceeded)],
        ])
        #expect(SyncMonitor.isQuotaExceeded(partial))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: quota])
        #expect(SyncMonitor.isQuotaExceeded(wrapped))
        #expect(!SyncMonitor.isQuotaExceeded(CKError(.networkUnavailable)))
        #expect(!SyncMonitor.isQuotaExceeded(nil))
    }

    @Test func historyPurgeKeepsRecentTransactions() async throws {
        // SQLite: in-memory stores keep no history.
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PersistenceController(mode: .local(directory: directory))
        _ = try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
        func transactionCount() throws -> Int {
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: .distantPast)
            request.resultType = .transactionsOnly
            let result = try persistence.viewContext.execute(request) as? NSPersistentHistoryResult
            return (result?.result as? [NSPersistentHistoryTransaction])?.count ?? 0
        }
        let before = try transactionCount()
        #expect(before > 0)

        await SyncMonitor.purgeHistory(before: .now.addingTimeInterval(-SyncMonitor.historyRetention), in: persistence.container)
        #expect(try transactionCount() == before, "recent history stays")

        await SyncMonitor.purgeHistory(before: .now.addingTimeInterval(60), in: persistence.container)
        #expect(try transactionCount() == 0, "older history is deleted")
    }

    @Test func remoteChangeBurstsArriveOnce() async throws {
        let name = Notification.Name("test.burst.\(UUID().uuidString)")
        let stream = AppEnvironment.coalescedNotifications(named: name, quiet: .milliseconds(100))
        let counter = Task {
            var count = 0
            for await _ in stream { count += 1 }
            return count
        }
        try await Task.sleep(for: .milliseconds(50))
        for _ in 0..<50 { NotificationCenter.default.post(name: name, object: nil) }
        try await Task.sleep(for: .milliseconds(400))
        NotificationCenter.default.post(name: name, object: nil)
        try await Task.sleep(for: .milliseconds(400))
        counter.cancel()
        #expect(await counter.value == 2, "one element per burst")
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
        #expect(space.memories?.count == 3)
        #expect(space.memories?.allSatisfy { $0.visiblePhotos.count == 1 && $0.locationName != nil } == true)
        #expect(space.places?.count == 4)
        #expect(space.goals?.count == 3)
        #expect(space.reminders?.count == 1)
        #expect(environment.moments.ideas(in: space).count == 1)
        let today = try #require(environment.moments.todayKey(in: space))
        let session = try #require(environment.moments.session(for: today, in: space))
        // Demo partner answered; the demo owner has not, so nothing is revealed yet.
        #expect(environment.moments.state(of: session, for: DemoData.ownerID)?.partner != nil)
        #expect(environment.moments.state(of: session, for: DemoData.ownerID)?.isRevealed == false)
        #expect(space.coverPhotoData != nil)
        #expect(environment.favorites.favoriteNoteIDs(for: DemoData.ownerID).count == 1)
        #expect(environment.isDemo)

        try DemoData.seedIfNeeded(environment)
        #expect(space.notes?.count == 3, "seeding is idempotent")
    }
    #endif
}
