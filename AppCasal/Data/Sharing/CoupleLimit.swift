//
//  CoupleLimit.swift
//  AppCasal
//

import CloudKit

/// Enforces that a couple space has exactly one owner and at most one partner.
nonisolated enum CoupleLimit {
    struct ParticipantSummary: Equatable {
        var isOwner: Bool
        var isRemoved: Bool
    }

    static let maximumPartners = 1

    /// Partners that hold or may claim a seat (invited, pending or accepted).
    static func activePartnerCount(_ participants: [ParticipantSummary]) -> Int {
        participants.filter { !$0.isOwner && !$0.isRemoved }.count
    }

    /// Whether the owner may invite someone. Only before any partner was ever added:
    /// a removed partner does not free the seat, because a new partner must start
    /// in a new space instead of receiving this couple's history.
    static func canInvite(_ participants: [ParticipantSummary]) -> Bool {
        participants.allSatisfy(\.isOwner)
    }

    /// Whether a share is acceptable for a couple: never more than one partner.
    static func isValidCouple(_ participants: [ParticipantSummary]) -> Bool {
        activePartnerCount(participants) <= maximumPartners
    }

    static func summaries(of share: CKShare) -> [ParticipantSummary] {
        share.participants.map {
            ParticipantSummary(isOwner: $0.role == .owner, isRemoved: $0.acceptanceStatus == .removed)
        }
    }
}
