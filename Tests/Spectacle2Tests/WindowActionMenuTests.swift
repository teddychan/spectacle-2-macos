import Testing
import AppKit
import DragonKit
import SpectacleCore
@testable import Spectacle2

// The Shortcuts pane's sections and the Status Menu's groups both read WindowActionGroup.all, so
// these orders are what the user sees in each.

private let expectedOrder: [WindowAction] = [
    .leftHalf, .rightHalf, .topHalf, .bottomHalf,
    .upperLeft, .upperRight, .lowerLeft, .lowerRight,
    .nextThird, .previousThird,
    .center, .fullscreen, .makeLarger, .makeSmaller,
    .nextDisplay, .previousDisplay,
    .undo, .redo,
]

@Test func shortcutsPaneSectionsListEveryActionOnceInPreferencesOrder() {
    #expect(WindowActionGroup.all.map(\.titleKey) == [
        "app.shortcuts.section.halves", "app.shortcuts.section.corners", "app.shortcuts.section.thirds",
        "app.shortcuts.section.sizing", "app.shortcuts.section.displays", "app.shortcuts.section.history",
    ])
    #expect(WindowActionGroup.all.flatMap(\.actions) == expectedOrder)
    #expect(Set(expectedOrder) == Set(WindowAction.allCases))
    #expect(expectedOrder.count == WindowAction.allCases.count)
}

// The Status Menu's Window Action items. Tests can't be granted Accessibility, so a simulated
// window on one 1440×875 visible frame stands in for the Target Window.

private final class FakeWindows: WindowAccessing {
    let window = AXUIElementCreateApplication(getpid())
    var frame = CGRect(x: 200, y: 200, width: 600, height: 400)
    var hasFocusedWindow = true
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 875)

    var isTrusted: Bool { true }
    func focusedWindow() -> AXUIElement? { hasFocusedWindow ? window : nil }
    func windowUnderCursor(atCocoaPoint p: CGPoint) -> AXUIElement? { window }
    func frame(of _: AXUIElement) -> CGRect? { frame }
    func setFrame(_ r: CGRect, of _: AXUIElement) { frame = r }
    func sourceVisibleFrame(for _: CGRect) -> CGRect { visibleFrame }
    func destinationVisibleFrame(for _: CGRect, direction _: Int) -> CGRect { visibleFrame }
}

private final class NoHotKeys: HotKeyRegistering {
    func register(_ map: [WindowAction: Shortcut]) -> Set<WindowAction> { [] }
    func unregisterAll() {}
}

private let everythingAvailable = WindowActionAvailability(isTrusted: true, hasTargetWindow: true, displayCount: 2)

@MainActor
private func menuItems(shortcuts: [WindowAction: Shortcut] = DefaultShortcuts.map,
                       availability: WindowActionAvailability = everythingAvailable,
                       controller: WindowActionController? = nil) -> [NSMenuItem] {
    let controller = controller ?? WindowActionController(makeHotKeys: { _ in NoHotKeys() }, windows: FakeWindows())
    return WindowActionMenu.items(shortcuts: shortcuts, availability: availability, controller: controller)
}

@MainActor
private func item(_ action: WindowAction, in items: [NSMenuItem]) -> NSMenuItem {
    items.first { $0.representedObject as? WindowAction == action }!
}

@MainActor
@Test func menuListsEveryActionOnceInGroupOrderWithSeparatorsOnlyBetweenGroups() {
    let items = menuItems()

    #expect(items.compactMap { $0.representedObject as? WindowAction } == expectedOrder)
    #expect(items.filter { !$0.isSeparatorItem }.map(\.title) == expectedOrder.map { L("app.action.\($0.rawValue)") })
    // One run per group and a trailing separator before the app items; an empty run would be a
    // leading or doubled separator.
    #expect(items.split(omittingEmptySubsequences: false, whereSeparator: \.isSeparatorItem).map(\.count)
        == [4, 4, 2, 4, 2, 2, 0])
}

@MainActor
@Test func everyMenuItemHasAnImage() {
    for item in menuItems() where !item.isSeparatorItem {
        #expect(item.image != nil, "no image for \(item.title)")
    }
}

@MainActor
@Test func menuShowsEachActionsShortcut() {
    let items = menuItems()

    let leftHalf = item(.leftHalf, in: items)
    #expect(leftHalf.keyEquivalent == String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1))
    #expect(leftHalf.keyEquivalentModifierMask == [.option, .command])

    let center = item(.center, in: items)
    #expect(center.keyEquivalent == "c")
    #expect(center.keyEquivalentModifierMask == [.option, .command])
}

@MainActor
@Test func menuShowsNoShortcutForAClearedOrUnlabelledKey() {
    var shortcuts = DefaultShortcuts.map
    shortcuts[.leftHalf] = nil
    shortcuts[.center] = Shortcut(keyCode: 99, modifiers: [.option, .command])   // F3: "Key 99"
    let items = menuItems(shortcuts: shortcuts)

    #expect(item(.leftHalf, in: items).keyEquivalent == "")
    #expect(item(.center, in: items).keyEquivalent == "")
    #expect(item(.rightHalf, in: items).keyEquivalent != "")
}

@MainActor
@Test func menuDisablesEveryActionWithoutAccessibilityOrATargetWindow() {
    let untrusted = WindowActionAvailability(isTrusted: false, hasTargetWindow: true, displayCount: 2)
    let noWindow = WindowActionAvailability(isTrusted: true, hasTargetWindow: false, displayCount: 2)
    for availability in [untrusted, noWindow] {
        #expect(menuItems(availability: availability).filter(\.isEnabled).isEmpty)
    }
    #expect(menuItems().filter { !$0.isSeparatorItem && !$0.isEnabled }.isEmpty)
}

@MainActor
@Test func menuDisablesOnlyTheDisplayMovesWithOneDisplay() {
    let oneDisplay = WindowActionAvailability(isTrusted: true, hasTargetWindow: true, displayCount: 1)
    let disabled = menuItems(availability: oneDisplay)
        .filter { !$0.isSeparatorItem && !$0.isEnabled }
        .compactMap { $0.representedObject as? WindowAction }
    #expect(disabled == [.nextDisplay, .previousDisplay])
}

@MainActor
@Test func choosingAMenuItemMovesTheTargetWindow() {
    let windows = FakeWindows()
    let controller = WindowActionController(makeHotKeys: { _ in NoHotKeys() }, windows: windows)
    let leftHalf = item(.leftHalf, in: menuItems(controller: controller))

    _ = (leftHalf.target as AnyObject).perform(leftHalf.action, with: leftHalf)

    #expect(windows.frame == CGRect(x: 0, y: 0, width: 720, height: 875))
}

@MainActor
@Test func targetWindowFollowsTheFrontmostAppsFocusedWindow() {
    let windows = FakeWindows()
    let controller = WindowActionController(makeHotKeys: { _ in NoHotKeys() }, windows: windows)
    #expect(controller.hasTargetWindow)
    windows.hasFocusedWindow = false
    #expect(!controller.hasTargetWindow)
}
