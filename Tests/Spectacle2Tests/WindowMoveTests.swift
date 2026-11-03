import Testing
import AppKit
import SpectacleCore
@testable import Spectacle2

// Keyboard actions and drag-to-snap move windows through the controller's one move path. Tests
// can't be granted Accessibility, so a simulated window and screen stand in for AX and NSScreen.

/// One window on one 1440×875 visible frame. Like a real app, it keeps the requested top-left
/// corner and picks its own size, here no narrower than `minimumWidth`.
private final class FakeWindows: WindowAccessing {
    // An element to identify the window by; never sent an AX message.
    let window = AXUIElementCreateApplication(getpid())
    var frame: CGRect
    let minimumWidth: CGFloat
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 875)

    init(_ frame: CGRect, minimumWidth: CGFloat = 0) {
        self.frame = frame
        self.minimumWidth = minimumWidth
    }

    var isTrusted: Bool { true }
    func focusedWindow() -> AXUIElement? { window }
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> AXUIElement? { window }
    func frame(of _: AXUIElement) -> CGRect? { frame }
    func setFrame(_ r: CGRect, of _: AXUIElement) {
        frame = CGRect(x: r.minX, y: r.minY, width: max(r.width, minimumWidth), height: r.height)
    }
    func sourceVisibleFrame(for _: CGRect) -> CGRect { visibleFrame }
    func destinationVisibleFrame(for _: CGRect, direction _: Int) -> CGRect { visibleFrame }
}

private let start = CGRect(x: 200, y: 200, width: 1000, height: 400)   // fits the minimum width
private let rightHalf = CGRect(x: 720, y: 0, width: 720, height: 875)

@MainActor
private func makeController(_ windows: FakeWindows) -> WindowActionController {
    WindowActionController(makeHotKeys: { _ in NoHotKeys() }, windows: windows)
}

private final class NoHotKeys: HotKeyRegistering {
    func register(_ map: [WindowAction: Shortcut]) -> Set<WindowAction> { [] }
    func unregisterAll() {}
}

@MainActor
private func snap(_ controller: WindowActionController, _ windows: FakeWindows, to rect: CGRect) {
    controller.apply(rect, to: windows.window, id: WindowID(element: windows.window),
                     currentFrame: windows.frame, record: true)
}

@MainActor
@Test func snapMovesAWindowWithAMinimumSizeBackOnScreen() {
    let windows = FakeWindows(start, minimumWidth: 1000)
    snap(makeController(windows), windows, to: rightHalf)
    #expect(windows.frame == CGRect(x: 440, y: 0, width: 1000, height: 875))
}

@MainActor
@Test func snapRecordsOneUndoStep() {
    let windows = FakeWindows(start, minimumWidth: 1000)
    let controller = makeController(windows)
    snap(controller, windows, to: rightHalf)
    let snapped = windows.frame

    controller.perform(.undo)
    #expect(windows.frame == start)
    controller.perform(.undo)                  // nothing older to go back to
    #expect(windows.frame == start)
    controller.perform(.redo)
    #expect(windows.frame == snapped)
}

@MainActor
@Test func unsnapRestoreRecordsNothing() {
    let windows = FakeWindows(rightHalf)
    let controller = makeController(windows)
    controller.apply(start, to: windows.window, id: WindowID(element: windows.window),
                     currentFrame: rightHalf, record: false)
    #expect(windows.frame == start)
    controller.perform(.undo)
    #expect(windows.frame == start)
}

@MainActor
@Test func keyboardActionRecordsOneUndoStepWhenTheWindowIsMovedTwice() {
    let windows = FakeWindows(start, minimumWidth: 1000)
    let controller = makeController(windows)
    controller.perform(.rightHalf)
    let moved = windows.frame
    #expect(moved == CGRect(x: 440, y: 0, width: 1000, height: 875))

    controller.perform(.undo)
    #expect(windows.frame == start)
    controller.perform(.undo)
    #expect(windows.frame == start)
    controller.perform(.redo)
    #expect(windows.frame == moved)
}
