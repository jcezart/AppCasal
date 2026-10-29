//
//  RootView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Decides between account problems, onboarding and the main tabs.
struct RootView: View {
    let environment: AppEnvironment

    @State private var space: CoupleSpace?
    /// Kept in state: `space` is the same object before and after the participant joins,
    /// so reading membership in `body` alone would not refresh the screen.
    @State private var isMember = false
    @State private var didLoad = false
    /// Paid period recorded in the space; in state because the space object does not
    /// change identity when the partner's device renews it.
    @State private var spaceAccessExpiresAt: Date?
    /// Joined through the partner's invitation (the space lives in the shared store).
    @State private var isParticipant = false
    /// The partner's subscription unlocked this iPhone while the paywall was up.
    @State private var isShowingPartnerUnlocked = false

    private var account: AccountService { environment.account }

    var body: some View {
        content
            .animation(.easeOut(duration: 0.25), value: didLoad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.canvas.ignoresSafeArea())
            .task {
                LaunchLog.mark("root task")
                #if DEBUG
                if environment.runMode == .demo {
                    try? DemoData.seedIfNeeded(environment)
                }
                #endif
                // With an identity already known on this device, show the space right
                // away; the iCloud check below runs without blocking the first screen.
                if account.status == .available {
                    reload()
                    LaunchLog.mark("first screen from local identity")
                }
                await account.refresh()
                LaunchLog.mark("account resolved")
                reload()
                environment.prepareMoments()
                // Also resyncs "Hoje, nós dois", which shares the pending limit.
                await environment.syncReminderNotifications()
                await environment.syncNoteAlerts()
                environment.scheduleNotificationRefresh()
            }
            .task {
                await environment.subscription.refresh()
                environment.recordSubscriptionAccess()
            }
            .task { await environment.subscription.observe() }
            .task { await account.observeAccountChanges() }
            .task { await environment.sync.observe(environment.persistence.container) }
            .task { await environment.network.observe() }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                    reload()
                    await environment.sync.refreshPendingChanges(in: environment.persistence.container)
                    // Reminders created or changed by the partner are scheduled here too.
                    await environment.syncReminderNotifications()
                    // Registers the note alert once the partner joins. "Hoje, nós dois"
                    // reminders follow remote changes in `observeChangesForNotifications`,
                    // which also runs when the app is woken in the background.
                    await environment.syncNoteAlerts()
                }
            }
            .task(id: isWaitingForSharedSpace) {
                // Importing an accepted space can take a while; besides remote-change
                // notifications, look again every few seconds until it arrives.
                while isWaitingForSharedSpace, !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    reload()
                }
            }
            .onChange(of: environment.sharing.acceptance) { reload() }
            .onChange(of: account.userRecordName, initial: true) {
                if let userRecordName = account.userRecordName {
                    environment.subscription.identify(userRecordName: userRecordName)
                }
                reload()
            }
            .onChange(of: environment.subscription.expirationDate) {
                environment.recordSubscriptionAccess()
                reload()
            }
            .onChange(of: access) { old, new in
                guard case .locked = old, new == .unlocked else { return }
                environment.subscription.dismissPaywall()
                if environment.subscription.isSubscribed != true {
                    isShowingPartnerUnlocked = true
                }
            }
            .alert("Seu par já assinou", isPresented: $isShowingPartnerUnlocked) {
                Button("Que bom!", role: .cancel) {}
            } message: {
                Text("Uma assinatura vale para os dois. Vocês estão liberados, sem pagar de novo.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let error = environment.persistence.loadError {
            ErrorBanner(message: error.localizedDescription)
                .padding(Spacing.screen)
        } else if account.status == .checking || !didLoad || Self.holdsWelcome || access == .checking {
            WelcomeView()
                .transition(.opacity)
        } else if case .locked(let reason) = access {
            PaywallGateView(environment: environment, reason: reason, checkPartnerAccess: partnerAccessCheck)
                .transition(.opacity)
        } else if account.status == .available, let userRecordName = account.userRecordName {
            if let space {
                if isMember {
                    MainTabView(environment: environment, space: space, userRecordName: userRecordName)
                } else {
                    JoinSpaceView(environment: environment, space: space, userRecordName: userRecordName, onJoined: reload)
                }
            } else if isWaitingForSharedSpace {
                AcceptingInvitationView()
                    .transition(.opacity)
            } else {
                CreateSpaceView(environment: environment, userRecordName: userRecordName, onCreated: reload)
            }
        } else {
            AccountUnavailableView(status: account.status) {
                Task { await account.refresh() }
            }
        }
    }

    /// DEBUG: `-AppCasalHoldWelcome YES` keeps the welcome screen up for design review.
    private static var holdsWelcome: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "AppCasalHoldWelcome")
        #else
        false
        #endif
    }

    /// The paywall stands at the door of the space, after onboarding (see `AccessRules`).
    private var access: AccessRules.Decision {
        environment.access(
            spaceAccessExpiresAt: spaceAccessExpiresAt,
            isInSpace: space != nil && isMember,
            isParticipant: isParticipant
        )
    }

    /// Both partners are in the space, so the other one may already pay for the couple.
    private var hasPartner: Bool {
        (space?.members?.count ?? 0) >= 2
    }

    private var partnerAccessCheck: (() async -> Bool)? {
        guard hasPartner else { return nil }
        return { await checkPartnerAccess() }
    }

    /// Before offering a purchase: the subscriber's date may be in iCloud but not here.
    /// True when that unlocked this iPhone.
    private func checkPartnerAccess() async -> Bool {
        await environment.syncSpaceAccessFromCloud()
        reload()
        return access == .unlocked
    }

    /// After accepting an invitation, until the shared space is on this iPhone.
    private var isWaitingForSharedSpace: Bool {
        guard space == nil else { return false }
        switch environment.sharing.acceptance {
        case .accepting, .accepted: return true
        case .idle, .rejected, .failed: return false
        }
    }

    private func reload() {
        let active = environment.spaces.activeSpace()
        space = active
        spaceAccessExpiresAt = active?.accessExpiresAt
        isParticipant = active.map { environment.spaces.role(in: $0) == .participant } ?? false
        isMember = active.flatMap { active in
            account.userRecordName.flatMap { environment.spaces.member(for: $0, in: active) }
        } != nil
        didLoad = true
    }
}
