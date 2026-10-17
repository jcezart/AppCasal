//
//  LaunchLog.swift
//  AppCasal
//

import Foundation
import os

/// Launch timing marks, readable with Console or `log show --predicate 'category == "launch"'`.
nonisolated enum LaunchLog {
    private static let logger = Logger(subsystem: "jc.app.dev.AppCasal", category: "launch")
    private static let start = ContinuousClock.now

    static func mark(_ step: StaticString) {
        let elapsed = ContinuousClock.now - start
        logger.log("\(step, privacy: .public): \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
    }
}
