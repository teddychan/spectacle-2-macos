import Testing
import Foundation
import SpectacleCore
@testable import Spectacle2

// Before the shortcut map had its own key, it and AppSettings both lived under "settings.v1",
// and whichever store failed to decode the other's value parked it under
// "settings.v1.unreadable". So a user's suite can hold either value in either place. Each test
// seeds one of those states the way the old build wrote it, then launches twice: both values
// must come back, and the second launch must change nothing.

private let settingsKey = "settings.v1"
private let unreadableKey = "settings.v1.unreadable"

private func customSettings() -> AppSettings {
    var settings = AppSettings()
    settings.dragSnapEnabled = false
    settings.gapSize = 8
    return settings
}

private func customMap() -> ShortcutStore.Map {
    var map = DefaultShortcuts.map
    map[.leftHalf] = Shortcut(keyCode: 99, modifiers: [.control])
    return map
}

private func seed(_ suiteName: String, _ key: String, _ value: some Encodable) {
    UserDefaults(suiteName: suiteName)?.set(try! JSONEncoder().encode(value), forKey: key)
}

/// Loads both stores in the app's launch order: SettingsModel is built before ShortcutStore.
@MainActor
private func launch(_ suiteName: String) -> (AppSettings, ShortcutStore.Map) {
    let settings = SettingsModel.makeStore(suiteName: suiteName).load()
    return (settings, ShortcutStore(suiteName: suiteName).load())
}

@MainActor
@Test func generalSettingsInTheSharedKeyStayPut() {
    let suiteName = "com.dragonapp.spectacle-2.tests.generalSettingsInTheSharedKeyStayPut"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customSettings())

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == customSettings())
        #expect(map == DefaultShortcuts.map)
    }
}

@MainActor
@Test func aShortcutMapInTheSharedKeyMovesToItsOwnKey() {
    let suiteName = "com.dragonapp.spectacle-2.tests.aShortcutMapInTheSharedKeyMovesToItsOwnKey"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customMap())

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == AppSettings())
        #expect(map == customMap())
    }
    // The map was moved, not parked aside as unreadable General settings.
    #expect(UserDefaults(suiteName: suiteName)?.object(forKey: unreadableKey) == nil)
}

@MainActor
@Test func aShortcutMapInTheSharedKeyAndGeneralSettingsMovedAsideAreBothRecovered() {
    let suiteName = "com.dragonapp.spectacle-2.tests.aShortcutMapInTheSharedKeyAndGeneralSettingsMovedAsideAreBothRecovered"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customMap())
    seed(suiteName, unreadableKey, customSettings())

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == customSettings())
        #expect(map == customMap())
    }
}

@MainActor
@Test func generalSettingsInTheSharedKeyAndAShortcutMapMovedAsideAreBothRecovered() {
    let suiteName = "com.dragonapp.spectacle-2.tests.generalSettingsInTheSharedKeyAndAShortcutMapMovedAsideAreBothRecovered"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customSettings())
    seed(suiteName, unreadableKey, customMap())

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == customSettings())
        #expect(map == customMap())
    }
}

@MainActor
@Test func generalSettingsMovedAsideAreRestoredWhenTheSharedKeyIsEmpty() {
    let suiteName = "com.dragonapp.spectacle-2.tests.generalSettingsMovedAsideAreRestoredWhenTheSharedKeyIsEmpty"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, unreadableKey, customSettings())

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == customSettings())
        #expect(map == DefaultShortcuts.map)
    }
}

@MainActor
@Test func theShortcutMapInTheSharedKeyWinsOverAnOlderOneMovedAside() {
    let suiteName = "com.dragonapp.spectacle-2.tests.theShortcutMapInTheSharedKeyWinsOverAnOlderOneMovedAside"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customMap())          // written after the aside copy was parked
    seed(suiteName, unreadableKey, DefaultShortcuts.map)

    for _ in 0..<2 {
        let (settings, map) = launch(suiteName)
        #expect(settings == AppSettings())
        #expect(map == customMap())
    }
}

@MainActor
@Test func editsMadeAfterTheMigrationSurviveTheNextLaunch() {
    let suiteName = "com.dragonapp.spectacle-2.tests.editsMadeAfterTheMigrationSurviveTheNextLaunch"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    seed(suiteName, settingsKey, customMap())
    seed(suiteName, unreadableKey, customSettings())
    _ = launch(suiteName)

    var settings = customSettings()
    settings.skipGapTopEdge = true
    SettingsModel.makeStore(suiteName: suiteName).save(settings)
    var map = customMap()
    map[.center] = nil
    ShortcutStore(suiteName: suiteName).save(map)

    let (relaunchedSettings, relaunchedMap) = launch(suiteName)
    #expect(relaunchedSettings == settings)
    #expect(relaunchedMap == map)
}
