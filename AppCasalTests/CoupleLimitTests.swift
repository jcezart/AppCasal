//
//  CoupleLimitTests.swift
//  AppCasalTests
//

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
}
