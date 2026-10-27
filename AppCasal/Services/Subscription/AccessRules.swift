//
//  AccessRules.swift
//  AppCasal
//

import Foundation

/// Who may use the app. It is fully paid (7-day free trial) and one subscription covers
/// the couple: the subscriber records the paid period in the space, and the partner
/// unlocks from it. Pure, so the rules are tested apart from StoreKit and Superwall.
nonisolated enum AccessRules {
    enum Decision: Equatable {
        case unlocked
        /// Subscription state not known yet (first seconds after launch).
        case checking
        case locked(Reason)
    }

    enum Reason: Equatable {
        /// Nobody in this couple subscribed (or this person has no space yet).
        case noSubscription
        /// The space's paid period ended: the subscriber's plan lapsed or their device
        /// has not renewed the date in a while.
        case coupleAccessEnded
    }

    /// The space's date is renewed only when the subscriber's iPhone runs the app (open
    /// or background refresh), so the partner keeps access a few days past it.
    static let partnerGrace: TimeInterval = 7 * 24 * 60 * 60

    struct Input: Equatable {
        /// False in demo, previews and tests: nothing is ever locked there.
        var isEnforced: Bool
        /// This person's own subscription; nil while unknown.
        var isSubscribed: Bool?
        /// An invitation is being accepted: joining a subscribed partner is free, so the
        /// paywall never stands between the invitation and the space.
        var isJoiningSpace: Bool
        /// Paid period recorded in the active space, if any.
        var spaceAccessExpiresAt: Date?
        var now: Date
    }

    static func decide(_ input: Input) -> Decision {
        guard input.isEnforced, input.isSubscribed != true, !input.isJoiningSpace else { return .unlocked }
        if let expiration = input.spaceAccessExpiresAt {
            if input.now < expiration.addingTimeInterval(partnerGrace) { return .unlocked }
            return input.isSubscribed == nil ? .checking : .locked(.coupleAccessEnded)
        }
        return input.isSubscribed == nil ? .checking : .locked(.noSubscription)
    }
}
