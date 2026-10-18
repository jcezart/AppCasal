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
                await environment.syncReminderNotifications()
                await environment.syncNoteAlerts()
            }
            .task { await account.observeAccountChanges() }
            .task { await environment.sync.observe(environment.persistence.container) }
            .task { await environment.network.observe() }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                    reload()
                    await environment.sync.refreshPendingChanges(in: environment.persistence.container)
                    // Reminders created or changed by the partner are scheduled here too.
                    await environment.syncReminderNotifications()
                    // Registers the note alert once the partner joins.
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
            .onChange(of: account.userRecordName) { reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let error = environment.persistence.loadError {
            ErrorBanner(message: error.localizedDescription)
                .padding(Spacing.screen)
        } else if account.status == .checking || !didLoad || Self.holdsWelcome {
            WelcomeView()
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
        isMember = active.flatMap { active in
            account.userRecordName.flatMap { environment.spaces.member(for: $0, in: active) }
        } != nil
        didLoad = true
    }
}
