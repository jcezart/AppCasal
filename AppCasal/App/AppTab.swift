//
//  AppTab.swift
//  AppCasal
//

import Foundation

enum AppTab: String, Hashable, CaseIterable {
    case home
    case map
    case memories
    case notes
    case goals

    /// First tab on launch. DEBUG builds accept `-AppCasalInitialTab <rawValue>`
    /// so screens can be captured from the command line.
    static var initial: AppTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "AppCasalInitialTab"), let tab = AppTab(rawValue: raw) {
            return tab
        }
        #endif
        return .home
    }
}
