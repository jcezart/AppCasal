//
//  PaletteContrastTests.swift
//  AppCasalTests
//

import Testing
import UIKit
@testable import AppCasal

/// WCAG 2 contrast of the text/background pairs the design system uses, in light and dark.
struct PaletteContrastTests {
    nonisolated struct Pair: Sendable, CustomTestStringConvertible {
        let foreground: String
        let background: String
        var testDescription: String { "\(foreground) on \(background)" }
    }

    nonisolated static let textPairs: [Pair] = [
        Pair(foreground: "Ink", background: "Canvas"),
        Pair(foreground: "Ink", background: "Surface"),
        Pair(foreground: "Ink", background: "SurfaceMuted"),
        Pair(foreground: "InkSecondary", background: "Canvas"),
        Pair(foreground: "InkSecondary", background: "Surface"),
        Pair(foreground: "InkSecondary", background: "SurfaceMuted"),
        Pair(foreground: "TerracottaText", background: "Canvas"),
        Pair(foreground: "TerracottaText", background: "Surface"),
        Pair(foreground: "TerracottaText", background: "SurfaceMuted"),
        Pair(foreground: "Leaf", background: "SurfaceMuted"),
        Pair(foreground: "OnTerracotta", background: "Terracotta"),
    ]

    @Test(arguments: textPairs, [UIUserInterfaceStyle.light, .dark])
    func textMeetsAA(_ pair: Pair, style: UIUserInterfaceStyle) throws {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let bundle = Bundle(for: PersistenceController.self)
        let foreground = try #require(UIColor(named: pair.foreground, in: bundle, compatibleWith: traits))
        let background = try #require(UIColor(named: pair.background, in: bundle, compatibleWith: traits))
        let ratio = Self.contrast(foreground.resolvedColor(with: traits), background.resolvedColor(with: traits))
        #expect(ratio >= 4.5, "\(pair.testDescription) (\(style == .dark ? "dark" : "light")): \(ratio)")
    }

    private static func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(_ color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &alpha)
        func channel(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
