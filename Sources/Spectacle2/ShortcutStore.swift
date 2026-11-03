import Foundation
import DragonKit
import SpectacleCore

/// Persists the action→shortcut map in the app's settings suite (so Backup & Restore captures it),
/// under its own key: `settings.v1` is AppSettings'.
@MainActor
final class ShortcutStore {
    typealias Map = [WindowAction: Shortcut]
    /// Keyed by `WindowAction.rawValue`. Every action the app knew about at save time has an
    /// entry, and `nil` is a shortcut the user cleared, so a missing entry means only "an action
    /// added since" and is the one case that gets its default.
    private typealias Stored = [String: Shortcut?]
    private static let key = "shortcuts.v1"
    private let store: DragonSettingsStore<Stored>

    init(suiteName: String) {
        Self.migrateSharedKey(suiteName: suiteName)
        store = DragonSettingsStore(suiteName: suiteName, defaultValue: [:], key: Self.key)
    }

    /// Older builds kept this map under `settings.v1` too, and the store that couldn't
    /// decode the other's value parked it under `settings.v1.unreadable`. So either value may be
    /// in either place. Move the map to its own key and put AppSettings back in `settings.v1`.
    /// Both stores call this before they load, and it is a no-op once the suite is untangled.
    static func migrateSharedKey(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let sharedKey = "settings.v1", unreadableKey = "settings.v1.unreadable"
        func decode<T: Decodable>(_ type: T.Type, at key: String) -> T? {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }

        // A map in the shared key is the newest an old build wrote, so it always wins. One parked
        // aside is older still, and is used only while the map has no key of its own yet.
        let sharedMap = decode(Map.self, at: sharedKey)
        let parkedMap = decode(Map.self, at: unreadableKey)
        if let map = sharedMap ?? (defaults.object(forKey: key) == nil ? parkedMap : nil) {
            // The old format can't tell a cleared shortcut from an unseen action, so only the
            // bound actions are recorded and the rest take their defaults, as before.
            let stored: Stored = map.reduce(into: [:]) { $0[$1.key.rawValue] = .some($1.value) }
            DragonSettingsStore(suiteName: suiteName, defaultValue: [:], key: key).save(stored)
        }
        // Recovered just now, or older than the map that was: either way it has nothing left to rescue.
        if parkedMap != nil { defaults.removeObject(forKey: unreadableKey) }

        if decode(AppSettings.self, at: sharedKey) == nil {
            if decode(AppSettings.self, at: unreadableKey) != nil,
               let data = defaults.data(forKey: unreadableKey) {
                defaults.set(data, forKey: sharedKey)
                defaults.removeObject(forKey: unreadableKey)
            } else if sharedMap != nil {
                defaults.removeObject(forKey: sharedKey)
            }
        }
    }

    func load() -> Map {
        let stored = store.load()
        var map: Map = [:]
        for action in WindowAction.allCases {
            // A stored `nil` (cleared) stays nil; only an absent entry falls through to the default.
            map[action] = stored[action.rawValue] ?? DefaultShortcuts.map[action]
        }
        return map
    }
    func save(_ map: Map) {
        store.save(Dictionary(uniqueKeysWithValues: WindowAction.allCases.map { ($0.rawValue, map[$0]) }))
    }
    func restoreDefaults() -> Map { save(DefaultShortcuts.map); return DefaultShortcuts.map }
}
