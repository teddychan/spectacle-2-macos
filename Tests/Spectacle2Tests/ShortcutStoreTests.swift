import Testing
import Foundation
import DragonKit
import SpectacleCore
@testable import Spectacle2

// ShortcutStore.load() merges DefaultShortcuts.map into a persisted map so actions added in a
// later app version still get a default binding, while a shortcut the user cleared stays
// cleared. Each test uses its own UserDefaults suite
// (never the app's real suiteName) and removes it afterward so reruns start clean.

@MainActor
@Test func loadWithNothingPersistedCoversEveryAction() {
    let suiteName = "com.dragonapp.spectacle-2.tests.loadWithNothingPersistedCoversEveryAction"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let map = ShortcutStore(suiteName: suiteName).load()

    for action in WindowAction.allCases {
        #expect(map[action] != nil, "missing binding for \(action)")
    }
}

@MainActor
@Test func loadMergesDefaultsForActionsOmittedFromThePersistedMap() {
    let suiteName = "com.dragonapp.spectacle-2.tests.loadMergesDefaultsForActionsOmittedFromThePersistedMap"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    var partial = DefaultShortcuts.map
    partial.removeValue(forKey: .center)
    partial.removeValue(forKey: .undo)
    let customBinding = Shortcut(keyCode: 99, modifiers: [.control])
    partial[.leftHalf] = customBinding

    // An older build's map: it has never seen the omitted actions. (`save` can't produce one any
    // more, since it records an action missing from the map as cleared.)
    UserDefaults(suiteName: suiteName)?.set(try! JSONEncoder().encode(partial), forKey: "settings.v1")
    let map = ShortcutStore(suiteName: suiteName).load()

    for action in WindowAction.allCases {
        #expect(map[action] != nil, "missing binding for \(action)")
    }
    #expect(map[.center] == DefaultShortcuts.map[.center])       // omitted -> filled from defaults
    #expect(map[.undo] == DefaultShortcuts.map[.undo])           // omitted -> filled from defaults
    #expect(map[.leftHalf] == customBinding)                     // persisted -> kept as stored
    #expect(map[.leftHalf] != DefaultShortcuts.map[.leftHalf])
}

@MainActor
@Test func restoreDefaultsReturnsAndPersistsExactlyDefaultShortcutsMap() {
    let suiteName = "com.dragonapp.spectacle-2.tests.restoreDefaultsReturnsAndPersistsExactlyDefaultShortcutsMap"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let store = ShortcutStore(suiteName: suiteName)
    store.save([.center: Shortcut(keyCode: 1, modifiers: [])])   // seed something non-default

    let restored = store.restoreDefaults()
    #expect(restored == DefaultShortcuts.map)

    // A fresh store reading the same suite must see the persisted defaults.
    let reloaded = ShortcutStore(suiteName: suiteName).load()
    #expect(reloaded == DefaultShortcuts.map)
}

// The General settings and the shortcut map share one suite, so each must survive the other
// being loaded and saved.

@MainActor
@Test func generalSettingsSurviveTheShortcutStoreLoadingAndSaving() {
    let suiteName = "com.dragonapp.spectacle-2.tests.generalSettingsSurviveTheShortcutStoreLoadingAndSaving"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    var general = AppSettings()
    general.dragSnapEnabled = false
    general.gapSize = 8
    SettingsModel.makeStore(suiteName: suiteName).save(general)

    let shortcuts = ShortcutStore(suiteName: suiteName)
    var map = shortcuts.load()
    let customBinding = Shortcut(keyCode: 99, modifiers: [.control])
    map[.center] = customBinding
    shortcuts.save(map)

    #expect(SettingsModel.makeStore(suiteName: suiteName).load() == general)
    #expect(ShortcutStore(suiteName: suiteName).load()[.center] == customBinding)
}

// A shortcut cleared with Delete is saved without that action, and must stay cleared.

@MainActor
@Test func aClearedShortcutStaysClearedAfterReload() {
    let suiteName = "com.dragonapp.spectacle-2.tests.aClearedShortcutStaysClearedAfterReload"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    let store = ShortcutStore(suiteName: suiteName)
    var map = store.load()
    map[.center] = nil
    store.save(map)

    let reloaded = ShortcutStore(suiteName: suiteName).load()
    #expect(reloaded[.center] == nil)
    #expect(reloaded[.leftHalf] == DefaultShortcuts.map[.leftHalf])
}
