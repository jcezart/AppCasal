//
//  SubscriptionTests.swift
//  AppCasalTests
//

import Foundation
import Testing
@testable import AppCasal

struct SubscriptionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func input(
        enforced: Bool = true,
        subscribed: Bool? = false,
        joining: Bool = false,
        spaceExpiration: Date? = nil
    ) -> AccessRules.Input {
        .init(isEnforced: enforced, isSubscribed: subscribed, isJoiningSpace: joining, spaceAccessExpiresAt: spaceExpiration, now: now)
    }

    @Test func demoAndTestsAreNeverLocked() {
        #expect(AccessRules.decide(input(enforced: false, subscribed: false)) == .unlocked)
        #expect(AccessRules.decide(input(enforced: false, subscribed: nil)) == .unlocked)
    }

    @Test func ownSubscriptionUnlocks() {
        #expect(AccessRules.decide(input(subscribed: true)) == .unlocked)
        #expect(AccessRules.decide(input(subscribed: true, spaceExpiration: now.addingTimeInterval(-60 * day))) == .unlocked)
    }

    @Test func withoutSubscriptionTheGateShows() {
        #expect(AccessRules.decide(input(subscribed: false)) == .locked(.noSubscription))
    }

    @Test func unknownStatusWaitsInsteadOfLocking() {
        #expect(AccessRules.decide(input(subscribed: nil)) == .checking)
        #expect(AccessRules.decide(input(subscribed: nil, spaceExpiration: now.addingTimeInterval(-30 * day))) == .checking)
    }

    @Test func partnerIsCoveredByTheSpaceUntilTheGraceEnds() {
        // Still paid, inside the grace, then past it.
        #expect(AccessRules.decide(input(spaceExpiration: now.addingTimeInterval(10 * day))) == .unlocked)
        #expect(AccessRules.decide(input(spaceExpiration: now.addingTimeInterval(-6 * day))) == .unlocked)
        #expect(AccessRules.decide(input(spaceExpiration: now.addingTimeInterval(-8 * day))) == .locked(.coupleAccessEnded))
    }

    @Test func acceptingAnInvitationIsNeverBlocked() {
        #expect(AccessRules.decide(input(subscribed: false, joining: true)) == .unlocked)
        #expect(AccessRules.decide(input(subscribed: nil, joining: true)) == .unlocked)
    }

    @Test func recordedAccessOnlyMovesForward() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let spaces = SpaceRepository(persistence: persistence)
        let space = try spaces.createSpace(ownerName: "Ana", userRecordName: "_owner-record-name")
        let later = now.addingTimeInterval(30 * day)

        try spaces.recordAccess(until: later, in: space, now: now)
        try spaces.recordAccess(until: now.addingTimeInterval(7 * day), in: space, now: now)

        #expect(space.accessExpiresAt == later)
    }

    @Test func superwallUserIDIsAStableUUIDv5() {
        let first = SubscriptionService.userID(for: "_abc123")
        #expect(first == SubscriptionService.userID(for: "_abc123"))
        #expect(first != SubscriptionService.userID(for: "_abc124"))
        // Version nibble 5, RFC 4122 variant.
        let text = first.uuidString
        #expect(Array(text)[14] == "5")
        #expect(["8", "9", "A", "B"].contains(Array(text)[19]))
    }
}
