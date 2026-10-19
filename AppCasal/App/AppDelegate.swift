//
//  AppDelegate.swift
//  AppCasal
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !AppEnvironment.isRunningTests else { return true }
        UNUserNotificationCenter.current().delegate = self
        // CloudKit mirroring relies on remote notifications to learn about changes.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // Completion-handler variants on purpose: the system expects these handlers on the
    // main thread, and the nonisolated `async` variants resume them from a background
    // executor, which can drop the tap instead of opening the app.

    /// A tapped note alert opens Recados; a "Hoje, nós dois" one opens its screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if NoteAlerts.isNoteAlert(userInfo) {
            AppEnvironment.shared.pendingTab = .notes
        } else if let route = MomentNotifications.route(from: userInfo) {
            // Local reminders, and answer alerts whose day the extension filled in.
            AppEnvironment.shared.pendingRoute = route
        } else if AnswerAlerts.isAnswerAlert(userInfo) {
            AppEnvironment.shared.pendingRoute = .explore
        } else if AnswerAlerts.isGameAlert(userInfo) {
            AppEnvironment.shared.pendingRoute = .game
        }
        completionHandler()
    }

    /// Shows note alerts while the app is in the foreground too.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
