//
//  AppCasalApp.swift
//  AppCasal
//

import OSLog
import SwiftUI

@main
struct AppCasalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment: AppEnvironment

    init() {
        LaunchLog.mark("app init")
        NavigationAppearance.apply()
        environment = AppEnvironment.shared
        environment.subscription.configure()
        LaunchLog.mark("environment ready")
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "AppCasalInitializeCloudKitSchema") {
            Task.detached(priority: .utility) {
                let log = Logger(subsystem: "jc.app.dev.AppCasal", category: "schema")
                do {
                    try PersistenceController.initializeDevelopmentSchema()
                    log.notice("CloudKit Development schema initialized")
                } catch {
                    log.error("CloudKit schema initialization failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
        #endif
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
