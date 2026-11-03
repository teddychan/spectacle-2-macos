import SwiftUI
import AppKit
import Carbon.HIToolbox
import DragonKit
import SpectacleCore

/// A click-to-record control: shows the current shortcut; while recording, the next key combo
/// (with ≥1 modifier) becomes the new Shortcut. Esc cancels; Delete clears.
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: Shortcut?
    var onChange: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onCapture = { sc in shortcut = sc; onChange(sc) }
        return b
    }
    func updateNSView(_ nsView: RecorderButton, context: Context) { nsView.shortcut = shortcut }

    final class RecorderButton: NSButton {
        var shortcut: Shortcut? { didSet { title = display } }
        var onCapture: ((Shortcut?) -> Void)?
        // Toggling this posts `.spectacleShortcutRecordingChanged` so global hot keys are
        // suspended while capturing (otherwise an already-bound combo fires its action instead of
        // being recorded), and observes the window so recording can't outlive the window it's in
        // — which would leave the hot keys suspended forever.
        private var recording = false {
            didSet {
                guard recording != oldValue else { return }
                title = display
                NotificationCenter.default.post(name: .spectacleShortcutRecordingChanged, object: recording)
                if recording { observeWindowResignKey() } else { stopObservingWindowResignKey() }
            }
        }
        private weak var observedWindow: NSWindow?

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            target = self; action = #selector(toggle)
            title = display
        }
        required init?(coder: NSCoder) { fatalError() }
        deinit { NotificationCenter.default.removeObserver(self) }

        private var display: String {
            recording ? L("app.shortcuts.recorder.recording")
                      : (shortcut?.displayString ?? L("app.shortcuts.recorder.record"))
        }

        @objc private func toggle() { recording.toggle(); if recording { window?.makeFirstResponder(self) } }
        override var acceptsFirstResponder: Bool { true }

        // End recording (restoring hot keys) whenever focus or the window's key status is lost —
        // e.g. the user clicks another field, switches apps, or closes Settings mid-recording.
        override func resignFirstResponder() -> Bool { recording = false; return super.resignFirstResponder() }
        @objc private func windowResignedKey() { recording = false }
        // AppKit does not call resignFirstResponder on a view removed from its window (e.g. the
        // menu bar's About replacing the Shortcuts pane), so end recording here too.
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow !== window { recording = false }
            super.viewWillMove(toWindow: newWindow)
        }

        private func observeWindowResignKey() {
            observedWindow = window
            guard let win = observedWindow else { return }
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowResignedKey),
                name: NSWindow.didResignKeyNotification, object: win)
        }
        private func stopObservingWindowResignKey() {
            if let win = observedWindow {
                NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: win)
            }
            observedWindow = nil
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) { recording = false; return }
            // End recording before reporting, so hot keys are back on when the pane applies the
            // new map and the conflicts it gets back are real.
            if event.keyCode == UInt16(kVK_Delete) { shortcut = nil; recording = false; onCapture?(nil); return }
            let mods = Self.modifierFlags(from: event.modifierFlags)
            guard !mods.isEmpty else { NSSound.beep(); return }   // require a modifier
            let sc = Shortcut(keyCode: event.keyCode, modifiers: mods)
            shortcut = sc; recording = false; onCapture?(sc)
        }

        static func modifierFlags(from ns: NSEvent.ModifierFlags) -> ModifierFlags {
            var m: ModifierFlags = []
            if ns.contains(.command) { m.insert(.command) }
            if ns.contains(.option)  { m.insert(.option) }
            if ns.contains(.control) { m.insert(.control) }
            if ns.contains(.shift)   { m.insert(.shift) }
            return m
        }
    }
}
