//
//  AppLinks.swift
//  AppCasal
//

import Foundation

/// Public pages about the app, the same ones listed in App Store Connect. Reachable from
/// the paywall and from "Nosso espaço" (App Review guidelines 3.1.2 and 5.1.1).
nonisolated enum AppLinks {
    /// Apple's standard license agreement, used as the terms of use.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://jcapps.dev.br/onlyus/privacidade/")!
    static let support = URL(string: "https://jcapps.dev.br/onlyus/suporte/")!
}
