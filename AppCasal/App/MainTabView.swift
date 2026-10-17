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

    var body: some View {
        TabView(selection: $selection) {
            Tab("Início", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        environment: environment,
                        space: space,
                        userRecordName: userRecordName,
                        showSpace: { isShowingSpace = true },
                        showNotes: { selection = .notes }
                    )
                }
            }
            Tab("Mapa", systemImage: "map", value: AppTab.map) {
                NavigationStack {
                    MapTabView()
                }
            }
            Tab("Memórias", systemImage: "photo.on.rectangle.angled", value: AppTab.memories) {
                NavigationStack {
                    MemoriesView()
                }
            }
            Tab("Recados", systemImage: "envelope", value: AppTab.notes) {
                NavigationStack {
                    NotesView(space: space, userRecordName: userRecordName)
                }
            }
            Tab("Metas", systemImage: "target", value: AppTab.goals) {
                NavigationStack {
                    GoalsView()
                }
            }
        }
        .tint(Palette.accentText)
        .sheet(isPresented: $isShowingSpace) {
            SpaceView(environment: environment, space: space, userRecordName: userRecordName)
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
