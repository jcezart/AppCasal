//
//  AppTab.swift
//  AppCasal
//

import Foundation

enum AppTab: String, Hashable, CaseIterable {
    case home
    /// "Hoje, nós dois". Metas lives at the end of Início: the iPhone bar holds five tabs.
    case moments
    case map
    case memories
    case notes

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
