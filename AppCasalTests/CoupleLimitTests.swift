//
//  CoupleLimitTests.swift
//  AppCasalTests
//

import CloudKit
import Testing
@testable import AppCasal

struct CoupleLimitTests {
    private let owner = CoupleLimit.ParticipantSummary(isOwner: true, isRemoved: false)
    private let partner = CoupleLimit.ParticipantSummary(isOwner: false, isRemoved: false)
    private let removedPartner = CoupleLimit.ParticipantSummary(isOwner: false, isRemoved: true)

    @Test func ownerAloneCanInvite() {
        #expect(CoupleLimit.canInvite([owner]))
        #expect(CoupleLimit.isValidCouple([owner]))
    }

    @Test func onePartnerFillsTheSpace() {
        #expect(!CoupleLimit.canInvite([owner, partner]))
        #expect(CoupleLimit.isValidCouple([owner, partner]))
    }

    @Test func secondPartnerIsRejected() {
        #expect(!CoupleLimit.isValidCouple([owner, partner, partner]))
    }

    @Test func removedPartnerDoesNotFreeTheSeat() {
        #expect(!CoupleLimit.canInvite([owner, removedPartner]))
        #expect(CoupleLimit.activePartnerCount([owner, removedPartner, partner]) == 1)
    }

    @Test func onlyAnAcceptedPartnerIsConnected() {
        let accepted = CoupleLimit.ParticipantSummary(isOwner: false, isRemoved: false, isAccepted: true)
        #expect(CoupleLimit.acceptedPartnerCount([owner, accepted]) == 1)
        // Invited but not joined yet, or removed: not connected.
        #expect(CoupleLimit.acceptedPartnerCount([owner, partner]) == 0)
        #expect(CoupleLimit.acceptedPartnerCount([owner, removedPartner]) == 0)
    }

    @Test func onlyOneSpacePerPerson() {
        let mine = CKRecordZone.ID(zoneName: "space-a", ownerName: "_owner")
        let other = CKRecordZone.ID(zoneName: "space-b", ownerName: "_someoneElse")
        #expect(ShareService.decision(currentRole: nil, currentZone: nil, invitedZone: other) == .accept)
        #expect(ShareService.decision(currentRole: .owner, currentZone: nil, invitedZone: other) == .ownsASpace)
        #expect(ShareService.decision(currentRole: .participant, currentZone: mine, invitedZone: mine) == .alreadyIn)
        #expect(ShareService.decision(currentRole: .participant, currentZone: mine, invitedZone: other) == .inAnotherSpace)
        // Share not on this iPhone yet: never join a second space blindly.
        #expect(ShareService.decision(currentRole: .participant, currentZone: nil, invitedZone: other) == .inAnotherSpace)
    }
}
