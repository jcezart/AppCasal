//
//  AppCasalApp.swift
//  AppCasal
//

import SwiftUI

@main
struct AppCasalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            if AppEnvironment.isRunningTests {
                Color.clear
            } else {
                SharingSpikeView(environment: environment)
                    .environment(\.managedObjectContext, environment.persistence.viewContext)
            }
        }
    }
}
