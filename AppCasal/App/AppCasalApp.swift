//
//  AppCasalApp.swift
//  AppCasal
//

import SwiftUI

@main
struct AppCasalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment: AppEnvironment

    init() {
        LaunchLog.mark("app init")
        NavigationAppearance.apply()
        environment = AppEnvironment.shared
        LaunchLog.mark("environment ready")
    }

    var body: some Scene {
        WindowGroup {
            if AppEnvironment.isRunningTests {
                Color.clear
            } else {
                RootView(environment: environment)
                    .environment(\.managedObjectContext, environment.persistence.viewContext)
            }
        }
        // Opportunistic extra; the reminders already scheduled do not depend on it.
        .backgroundTask(.appRefresh(AppEnvironment.refreshTaskIdentifier)) {
            await AppEnvironment.shared.refreshNotificationsInBackground()
        }
    }
}
