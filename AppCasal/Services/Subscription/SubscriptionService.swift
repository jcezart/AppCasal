//
//  SubscriptionService.swift
//  AppCasal
//

import Combine
import CryptoKit
import Foundation
import Observation
import OSLog
import StoreKit
import SuperwallKit

/// The paid plan: Superwall shows the paywall and runs the purchase; StoreKit on this
/// iPhone says whether the plan is active (works offline, right at launch). Superwall's
/// own status only adds to it, never locks on its own.
@Observable
final class SubscriptionService {
    /// Public key of the Superwall project "OnlyUs": it only fetches paywalls and reports
    /// events, so it is meant to ship in the app.
    static let superwallAPIKey = "pk_kTWlZ_UrcygRIm8eriRkl"
    /// Placement of the paywall shown before the app opens. In the Superwall dashboard it
    /// belongs to a campaign whose paywall is Gated.
    static let gatePlacement = "app_launch_gate"
    /// Subscription group "OnlyUs", both with a 7-day free trial (introductory offer).
    static let productIDs: Set<String> = [
        "jc.app.dev.AppCasal.premium.monthly",
        "jc.app.dev.AppCasal.premium.yearly",
    ]

    /// False in demo, previews and tests: no SDK, no StoreKit, nothing locked.
    let isEnforced: Bool
    /// This person's own plan; nil until StoreKit answers after launch.
    private(set) var isSubscribed: Bool?
    /// End of this person's current paid period (trial included), when subscribed.
    private(set) var expirationDate: Date?
    /// Set when the paywall could not be shown (no network, no campaign yet).
    var paywallProblem: String?
    /// Prices after the trial, from the App Store in the person's currency
    /// ("R$ 14,90/mês ou R$ 89,90/ano"); nil until loaded or offline.
    private(set) var priceSummary: String?

    private let log = Logger(subsystem: "jc.app.dev.AppCasal", category: "subscription")

    init(isEnforced: Bool) {
        self.isEnforced = isEnforced
    }

    /// Once, at launch, before any screen.
    func configure() {
        guard isEnforced else { return }
        Superwall.configure(apiKey: Self.superwallAPIKey)
    }

    /// Ties purchases to the iCloud identity, so the subscription follows the person
    /// across reinstalls. Superwall needs a UUID that is not guessable from outside:
    /// derived from the iCloud record name, which never leaves Apple's servers otherwise.
    func identify(userRecordName: String) {
        guard isEnforced else { return }
        Superwall.shared.identify(userId: Self.userID(for: userRecordName).uuidString)
    }

    /// Reads the active plan from StoreKit (local receipt, no network needed).
    func refresh(now: Date = .now) async {
        guard isEnforced else { return }
        var latest: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            let expiration = transaction.expirationDate ?? .distantFuture
            guard expiration > now else { continue }
            latest = max(latest ?? expiration, expiration)
        }
        expirationDate = latest
        isSubscribed = latest != nil || Superwall.shared.subscriptionStatus.isActive
    }

    /// Loads the plans' prices for the gate screen, so the free trial is never shown without
    /// what it costs afterwards (App Review guideline 3.1.2).
    func loadPrices() async {
        guard isEnforced, priceSummary == nil,
              let products = try? await Product.products(for: Self.productIDs) else { return }
        let monthly = products.first { $0.subscription?.subscriptionPeriod.unit == .month }
        let yearly = products.first { $0.subscription?.subscriptionPeriod.unit == .year }
        guard let monthly, let yearly else { return }
        priceSummary = String(localized: "7 dias grátis na primeira assinatura. Depois, \(monthly.displayPrice)/mês ou \(yearly.displayPrice)/ano, com renovação automática.")
    }

    /// Follows renewals, refunds and purchases made on other devices, plus Superwall's
    /// own status (purchases made from its paywall). Runs for the app's lifetime.
    func observe() async {
        guard isEnforced else { return }
        async let transactions: Void = {
            for await _ in Transaction.updates {
                await refresh()
            }
        }()
        async let superwall: Void = {
            for await _ in Superwall.shared.$subscriptionStatus.map(\.isActive).removeDuplicates().values {
                await refresh()
            }
        }()
        _ = await (transactions, superwall)
    }

    /// Shows the gate paywall. Access is decided by `refresh`, never by the callbacks: a
    /// missing campaign runs the feature block right away, and that must not unlock.
    func presentPaywall() {
        guard isEnforced else { return }
        paywallProblem = nil
        let handler = PaywallPresentationHandler()
        handler.onDismiss { [weak self] _, _ in
            Task { await self?.refresh() }
        }
        handler.onError { [weak self] error in
            self?.log.error("Paywall failed: \(String(describing: error), privacy: .public)")
            self?.paywallProblem = String(localized: "Não foi possível abrir os planos agora. Confira a conexão e tente de novo.")
        }
        handler.onSkip { [weak self] reason in
            self?.log.notice("Paywall skipped: \(String(describing: reason), privacy: .public)")
            Task { await self?.refresh() }
        }
        Superwall.shared.register(placement: Self.gatePlacement, handler: handler) { [weak self] in
            Task { await self?.refresh() }
        }
    }

    /// Closes the paywall once the couple is unlocked by the partner's subscription:
    /// the app opens underneath, but Superwall's screen stays on top until dismissed.
    func dismissPaywall() {
        guard isEnforced, Superwall.shared.isPaywallPresented else { return }
        Superwall.shared.dismiss()
    }

    /// "Restaurar compras": syncs with the App Store, then reads the plan again.
    func restore() async {
        guard isEnforced else { return }
        _ = await Superwall.shared.restorePurchases()
        try? await AppStore.sync()
        await refresh()
    }

    /// Stable UUID from the iCloud record name (SHA-256, shaped as a version 5 UUID).
    nonisolated static func userID(for userRecordName: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(userRecordName.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
