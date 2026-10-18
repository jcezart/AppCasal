//
//  MainTabView.swift
//  AppCasal
//

import SwiftUI

/// The five main tabs. Native `TabView`: on iOS 26 the tab bar is Liquid Glass.
struct MainTabView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @State private var selection = AppTab.initial
    @State private var isShowingSpace = false
    @State private var isShowingNotificationPrompt = false
    @State private var isShowingInvitePrompt = false
    /// The prompt saved the share; the share sheet opens once the prompt has closed.
    @State private var invitesAfterPrompt = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("Início", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        environment: environment,
                        space: space,
                        userRecordName: userRecordName,
                        showSpace: { isShowingSpace = true },
                        showTab: { selection = $0 }
                    )
                }
            }
            Tab("Mapa", systemImage: "map", value: AppTab.map) {
                NavigationStack {
                    MapTabView(environment: environment, space: space, userRecordName: userRecordName)
                }
            }
            Tab("Memórias", systemImage: "photo.on.rectangle.angled", value: AppTab.memories) {
                NavigationStack {
                    MemoriesView(environment: environment, space: space, userRecordName: userRecordName)
                }
            }
            Tab("Recados", systemImage: "envelope", value: AppTab.notes) {
                NavigationStack {
                    NotesView(environment: environment, space: space, userRecordName: userRecordName)
                }
            }
            Tab("Metas", systemImage: "target", value: AppTab.goals) {
                NavigationStack {
                    GoalsView(environment: environment, space: space, userRecordName: userRecordName)
                }
            }
        }
        .tint(Palette.accentText)
        .sheet(isPresented: $isShowingSpace) {
            SpaceView(environment: environment, space: space, userRecordName: userRecordName)
        }
        .onChange(of: environment.pendingTab, initial: true) {
            if let tab = environment.pendingTab {
                selection = tab
                environment.pendingTab = nil
            }
        }
        .sheet(isPresented: $isShowingNotificationPrompt) {
            NotificationPromptView(environment: environment)
        }
        .sheet(isPresented: $isShowingInvitePrompt, onDismiss: afterInvitePrompt) {
            InvitePartnerPromptView(environment: environment, space: space) { invitesAfterPrompt = true }
        }
        .task {
            // Right after creating the space, inviting comes first; notifications after.
            if environment.offersInvitation {
                environment.offersInvitation = false
                isShowingInvitePrompt = true
            } else {
                await offerNotificationsIfNeeded()
            }
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.bool(forKey: "AppCasalShowSpace") {
                isShowingSpace = true
            }
        }
        #endif
    }

    private func afterInvitePrompt() {
        if invitesAfterPrompt {
            invitesAfterPrompt = false
            // The share was saved by the prompt; failures show again from the Início card.
            Task { try? await environment.sharing.presentInvitation(for: space) }
        } else {
            Task { await offerNotificationsIfNeeded() }
        }
    }

    /// Asked once, after the space is ready, with an explanation first.
    private func offerNotificationsIfNeeded() async {
        guard NotificationPromptView.shouldOffer(environment) else { return }
        await environment.reminderNotifications.refreshAuthorization()
        if environment.reminderNotifications.authorization == .notDetermined {
            isShowingNotificationPrompt = true
        }
    }
}
