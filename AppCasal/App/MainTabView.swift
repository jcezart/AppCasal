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
        .task {
            // Asked once, after the space is ready, with an explanation first.
            guard NotificationPromptView.shouldOffer(environment) else { return }
            await environment.reminderNotifications.refreshAuthorization()
            if environment.reminderNotifications.authorization == .notDetermined {
                isShowingNotificationPrompt = true
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
}
