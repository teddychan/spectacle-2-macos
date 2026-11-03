import Testing
import AppKit
import Carbon.HIToolbox
import SpectacleCore
@testable import Spectacle2

// Global hot keys are suspended exactly while a shortcut recorder is recording. The controller
// tests use a stub instead of HotKeyManager, so no real Carbon hot key is ever claimed; the
// recorder tests use an offscreen window that is never shown.

/// Records what `register` / `unregisterAll` leave registered, in place of Carbon.
private final class StubHotKeys: HotKeyRegistering {
    var registered: [WindowAction: Shortcut] = [:]
    var claimedElsewhere: Set<WindowAction> = []

    func register(_ map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        registered = map.filter { !claimedElsewhere.contains($0.key) }
        return claimedElsewhere.intersection(map.keys)
    }
    func unregisterAll() { registered = [:] }
}

@MainActor
private func makeController() -> (WindowActionController, StubHotKeys) {
    let hotKeys = StubHotKeys()
    return (WindowActionController(makeHotKeys: { _ in hotKeys }), hotKeys)
}

/// Every `.spectacleShortcutRecordingChanged` value posted while it is alive.
private final class RecordingChanges: @unchecked Sendable {
    private(set) var values: [Bool] = []
    private var token: NSObjectProtocol?

    init() {
        token = NotificationCenter.default.addObserver(
            forName: .spectacleShortcutRecordingChanged, object: nil, queue: nil
        ) { [unowned self] note in self.values.append((note.object as? Bool) ?? false) }
    }
    func stop() { token.map(NotificationCenter.default.removeObserver) }
}

@MainActor
private func makeWindowWithRecorder() -> (NSWindow, ShortcutRecorderField.RecorderButton) {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 300, height: 100),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let recorder = ShortcutRecorderField.RecorderButton(frame: NSRect(x: 10, y: 10, width: 200, height: 28))
    window.contentView!.addSubview(recorder)
    return (window, recorder)
}

@MainActor
@Test func mapChangedWhileRecordingIsRegisteredOnlyWhenRecordingEnds() {
    let (controller, hotKeys) = makeController()
    controller.start(with: DefaultShortcuts.map)
    controller.setRecording(true)
    #expect(hotKeys.registered.isEmpty)

    var changed = DefaultShortcuts.map
    changed[.leftHalf] = Shortcut(keyCode: UInt16(kVK_ANSI_K), modifiers: [.control, .option])
    controller.updateShortcuts(changed)        // e.g. Restore Defaults clicked mid-recording
    #expect(hotKeys.registered.isEmpty)

    controller.setRecording(false)
    #expect(hotKeys.registered == changed)
}

@MainActor
@Test func updateShortcutsReportsConflictsWhenNotRecording() {
    let (controller, hotKeys) = makeController()
    hotKeys.claimedElsewhere = [.center]
    controller.start(with: DefaultShortcuts.map)

    #expect(controller.updateShortcuts(DefaultShortcuts.map) == [.center])
}

@MainActor
@Test func recorderRemovedFromItsWindowWhileRecordingEndsRecording() {
    let changes = RecordingChanges()
    defer { changes.stop() }
    let (window, recorder) = makeWindowWithRecorder()
    defer { window.close() }

    recorder.performClick(nil)
    #expect(changes.values == [true])

    recorder.removeFromSuperview()             // SwiftUI replacing the Shortcuts pane
    #expect(changes.values == [true, false])
}

@MainActor
@Test func captureEndsRecordingBeforeReportingTheShortcut() throws {
    let changes = RecordingChanges()
    defer { changes.stop() }
    let (window, recorder) = makeWindowWithRecorder()
    defer { window.close() }
    var changesWhenReported: [Bool] = []
    var reported: Shortcut?
    recorder.onCapture = { sc in reported = sc; changesWhenReported = changes.values }

    recorder.performClick(nil)
    let event = try #require(NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, characters: "\u{0B}",
        charactersIgnoringModifiers: "k", isARepeat: false, keyCode: UInt16(kVK_ANSI_K)))
    recorder.keyDown(with: event)

    // The pane applies the new map from onCapture; hot keys must already be back on by then, so
    // that it registers and its conflict set is real.
    #expect(reported == Shortcut(keyCode: UInt16(kVK_ANSI_K), modifiers: [.control, .option]))
    #expect(changesWhenReported == [true, false])
}
