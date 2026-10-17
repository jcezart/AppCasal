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
            }
            .task { await account.observeAccountChanges() }
            .task { await environment.sync.observe(environment.persistence.container) }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
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
                if environment.spaces.member(for: userRecordName, in: space) != nil {
                    MainTabView(environment: environment, space: space, userRecordName: userRecordName)
                } else {
                    JoinSpaceView(environment: environment, space: space, userRecordName: userRecordName, onJoined: reload)
                }
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

    private func reload() {
        space = environment.spaces.activeSpace()
        didLoad = true
    }
}
