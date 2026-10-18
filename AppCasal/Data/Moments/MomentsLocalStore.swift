//
//  MomentsLocalStore.swift
//  AppCasal
//

import Foundation

/// Personal state of "Hoje, nós dois" kept only on this device, never in the couple
/// space: answer and game drafts, recent gestures and revive suggestions, the date
/// filters. Keys include the space ID so another space never reads them.
nonisolated struct MomentsLocalStore {
    private let defaults: UserDefaults
    private let spaceKey: String

    init(spaceID: UUID?, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        spaceKey = spaceID?.uuidString ?? "none"
    }

    private func key(_ name: String) -> String { "moments.\(spaceKey).\(name)" }

    // MARK: Drafts (not sent; never shown to the partner)

    func answerDraft(for dayKey: String) -> String {
        defaults.string(forKey: key("draft.\(dayKey)")) ?? ""
    }

    func setAnswerDraft(_ text: String, for dayKey: String) {
        if text.trimmed.isEmpty {
            defaults.removeObject(forKey: key("draft.\(dayKey)"))
        } else {
            defaults.set(text, forKey: key("draft.\(dayKey)"))
        }
    }

    func gameDraft(for roundID: UUID) -> [GameEntry] {
        GameRules.decode([GameEntry].self, from: defaults.string(forKey: key("game.\(roundID.uuidString)"))) ?? []
    }

    func setGameDraft(_ entries: [GameEntry]?, for roundID: UUID) {
        if let entries, let json = GameRules.encode(entries) {
            defaults.set(json, forKey: key("game.\(roundID.uuidString)"))
        } else {
            defaults.removeObject(forKey: key("game.\(roundID.uuidString)"))
        }
    }

    // MARK: Recent suggestions

    var recentGestures: [String] {
        defaults.stringArray(forKey: key("gestures.recent")) ?? []
    }

    var currentGesture: String? {
        get { defaults.string(forKey: key("gestures.current")) }
        nonmutating set { defaults.set(newValue, forKey: key("gestures.current")) }
    }

    /// Done gestures; kept on this device only, so the partner is never told what was planned.
    var completedGestures: [String] {
        defaults.stringArray(forKey: key("gestures.done")) ?? []
    }

    func noteGestureShown(_ id: String) {
        let list = (recentGestures.filter { $0 != id } + [id]).suffix(GestureRules.recentLimit)
        defaults.set(Array(list), forKey: key("gestures.recent"))
    }

    func noteGestureDone(_ id: String) {
        defaults.set(Array((completedGestures + [id]).suffix(200)), forKey: key("gestures.done"))
    }

    var recentRevives: [UUID] {
        (defaults.stringArray(forKey: key("revive.recent")) ?? []).compactMap(UUID.init(uuidString:))
    }

    func noteReviveShown(_ id: UUID) {
        let list = (recentRevives.filter { $0 != id } + [id]).suffix(ReviveRules.recentLimit)
        defaults.set(list.map(\.uuidString), forKey: key("revive.recent"))
    }
}
