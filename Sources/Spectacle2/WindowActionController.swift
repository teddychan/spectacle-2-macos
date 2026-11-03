import AppKit
import ApplicationServices
import SpectacleCore

/// What the controller needs from the global hot-key layer: `HotKeyManager` in the app, a stub in
/// tests (which must never claim real Carbon hot keys).
protocol HotKeyRegistering: AnyObject {
    @discardableResult func register(_ map: [WindowAction: Shortcut]) -> Set<WindowAction>
    func unregisterAll()
}

extension HotKeyManager: HotKeyRegistering {}

/// What the controller needs from Accessibility and the displays: `AccessibilityElement` and
/// `ScreenProvider` in the app, a simulated window in tests (which can't be granted Accessibility).
protocol WindowAccessing: AnyObject {
    var isTrusted: Bool { get }
    func focusedWindow() -> AXUIElement?
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> AXUIElement?
    func frame(of window: AXUIElement) -> CGRect?
    func setFrame(_ cocoaRect: CGRect, of window: AXUIElement)
    func sourceVisibleFrame(for rect: CGRect) -> CGRect
    func destinationVisibleFrame(for rect: CGRect, direction: Int) -> CGRect
}

extension AccessibilityElement: WindowAccessing {
    var isTrusted: Bool { AXIsProcessTrusted() }
    func sourceVisibleFrame(for rect: CGRect) -> CGRect { ScreenProvider.sourceVisibleFrame(for: rect) }
    func destinationVisibleFrame(for rect: CGRect, direction: Int) -> CGRect {
        ScreenProvider.destinationVisibleFrame(for: rect, direction: direction)
    }
}

/// Glues hot keys → geometry → AX, and owns undo/redo history.
/// Invariant: only geometry moves call `history.record`; undo/redo mutate history themselves.
@MainActor
final class WindowActionController {
    private var history = WindowHistory()
    private let ax: any WindowAccessing
    private let makeHotKeys: (@escaping @Sendable (WindowAction) -> Void) -> any HotKeyRegistering
    private var hotKeys: (any HotKeyRegistering)?
    /// The active shortcut map, kept so hot keys can be restored after a recording session.
    private var currentMap: [WindowAction: Shortcut] = [:]
    /// Whether a shortcut recorder is capturing; while it is, no hot key is registered.
    private var recording = false

    /// Supplies the current gap on every action, so changing the setting takes effect immediately
    /// without re-registering hot keys. Defaults to no gap until the app wires it.
    var gapProvider: @MainActor () -> (size: CGFloat, skipTop: Bool) = { (0, false) }

    init(makeHotKeys: @escaping (@escaping @Sendable (WindowAction) -> Void) -> any HotKeyRegistering
            = { HotKeyManager(onAction: $0) },
         windows: any WindowAccessing = AccessibilityElement()) {
        self.makeHotKeys = makeHotKeys
        self.ax = windows
    }

    /// Starts the engine, returning the actions whose global hot key could not be registered
    /// (conflicts), so the UI can flag them.
    @discardableResult
    func start(with map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        currentMap = map
        let hk = makeHotKeys { [weak self] action in
            MainActor.assumeIsolated { self?.perform(action) }
        }
        let failed = hk.register(map)
        hotKeys = hk
        return failed
    }

    /// Re-registers after a rebind. Returns the actions that failed to register (conflicts).
    /// While recording (e.g. Restore Defaults clicked mid-recording) it only stores the map, which
    /// `setRecording(false)` registers, and returns no conflicts: nothing was registered to fail.
    @discardableResult
    func updateShortcuts(_ map: [WindowAction: Shortcut]) -> Set<WindowAction> {
        currentMap = map
        guard !recording else { return [] }
        return hotKeys?.register(map) ?? []
    }

    /// Suspends global hot keys while a shortcut is being recorded, so pressing a combo that is
    /// already bound lands in the recorder instead of triggering that action; restores the active
    /// map, including any change stored meanwhile, when recording ends. Must be balanced — every
    /// `true` is followed by a `false` (the recorder guarantees this even if its window closes or
    /// its pane is replaced mid-recording).
    func setRecording(_ recording: Bool) {
        self.recording = recording
        if recording {
            hotKeys?.unregisterAll()
        } else {
            _ = hotKeys?.register(currentMap)
        }
    }

    func perform(_ action: WindowAction) {
        // Without Accessibility permission every action is a silent no-op. Trigger the system
        // prompt so the first hot-key press explains why nothing happened and offers to open
        // System Settings; macOS shows it once and suppresses it thereafter until granted.
        guard ensureTrusted() else { return }
        guard let window = ax.focusedWindow(), let current = ax.frame(of: window) else { return }
        let id = WindowID(element: window)
        let source = ax.sourceVisibleFrame(for: current)

        // Decision logic lives in the pure, unit-tested WindowActionResolver (which enforces the
        // "only geometry moves record history" invariant); the controller just supplies I/O.
        let dir = WindowActionResolver.displayDirection(for: action)
        let dest = dir == 0 ? source : ax.destinationVisibleFrame(for: current, direction: dir)
        let (gapSize, skipTop) = gapProvider()
        let outcome = WindowActionResolver.resolve(
            action: action, windowID: id, currentFrame: current,
            sourceVisibleFrame: source, destinationVisibleFrame: dest,
            gap: gapSize, skipGapTopEdge: skipTop, history: &history)
        // Skip the AX write when the frame wouldn't change (e.g. Fullscreen/Center pressed twice,
        // or a bounded resize already at its limit): the round-trip is pure overhead. History
        // semantics are untouched — the resolver has already recorded per its parity rules.
        guard case .move(let newRect) = outcome, newRect != current else { return }
        move(window, to: newRect)
    }

    /// The one way a window is moved, keyboard action or snap. `WindowMover` writes the frame,
    /// reads it back and corrects it if the app refused the size, inside the visible frame of the
    /// screen it was sent to. History is untouched: the extra writes finish the same action.
    private func move(_ window: AXUIElement, to rect: CGRect) {
        WindowMover.move(to: rect, visibleFrame: ax.sourceVisibleFrame(for: rect),
                         setFrame: { ax.setFrame($0, of: window) }, frame: { ax.frame(of: window) })
    }

    /// Whether Accessibility permission is granted; when it isn't, asks macOS to show its
    /// "grant access" prompt (a no-op if one is already pending or the user dismissed it).
    private func ensureTrusted() -> Bool {
        if ax.isTrusted { return true }
        // Literal key value of `kAXTrustedCheckOptionPrompt` — referencing the imported global
        // `var` directly isn't concurrency-safe under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }

    /// The window under a Cocoa point and its current Cocoa frame — for drag-snap acquisition.
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> (window: AXUIElement, id: WindowID, frame: CGRect)? {
        guard ax.isTrusted, let w = ax.windowUnderCursor(atCocoaPoint: p),
              let f = ax.frame(of: w) else { return nil }
        return (w, WindowID(element: w), f)
    }

    /// Current Cocoa frame of a known window.
    func frame(of window: AXUIElement) -> CGRect? { ax.frame(of: window) }

    /// Apply a frame from outside the hot-key path (drag-snap). `record: true` pushes the pre-move
    /// frame so ⌘Z undoes the snap; `record: false` (unsnap-restore) does not touch history.
    /// Either way the window moves exactly as a keyboard action moves it.
    func apply(_ newRect: CGRect, to window: AXUIElement, id: WindowID, currentFrame: CGRect, record: Bool) {
        guard ax.isTrusted else { return }
        if record { history.record(currentFrame, for: id) }
        move(window, to: newRect)
    }
}
