//
//  GoalStepsObserver.swift
//  AppCasal
//

import Combine
import CoreData
import SwiftUI

/// Redraws `content` whenever a step of `goal` changes. Ticking a step writes only the
/// step record (fewer conflicts), so observing the goal alone left progress stale,
/// both after a local tap and when the partner's changes were merged.
struct GoalStepsObserver<Content: View>: View {
    let goal: Goal
    @ViewBuilder let content: () -> Content

    @State private var revision = 0

    init(goal: Goal, @ViewBuilder content: @escaping () -> Content) {
        self.goal = goal
        self.content = content
    }

    var body: some View {
        // Reading the revision makes the content depend on it.
        let _ = revision
        content()
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: goal.managedObjectContext)) { notification in
                if touchesSteps(notification) {
                    revision &+= 1
                }
            }
    }

    private func touchesSteps(_ notification: Notification) -> Bool {
        let keys = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSRefreshedObjectsKey]
        return keys.contains { key in
            (notification.userInfo?[key] as? Set<NSManagedObject>)?.contains { ($0 as? GoalStep)?.goal == goal } ?? false
        }
    }
}
