import Testing
import AppKit
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
