import Testing
@testable import SpectacleCore

// The fixed thirds ship unbound, so they take no key from an existing setup; every other action
// keeps its classic Spectacle default.
@Test func everyActionButTheFixedThirdsHasADefault() {
    let unbound: Set<WindowAction> = [
        .leftThird, .centerThird, .rightThird, .leftTwoThirds, .centerTwoThirds, .rightTwoThirds,
    ]
    for action in WindowAction.allCases {
        #expect((DefaultShortcuts.map[action] == nil) == unbound.contains(action), "\(action)")
    }
}

@Test func classicBindingsAreCorrect() {
    #expect(DefaultShortcuts.map[.center] == Shortcut(keyCode: 8, modifiers: [.option, .command]))       // ⌥⌘C
    #expect(DefaultShortcuts.map[.leftHalf]?.displayString == "⌥⌘←")
    #expect(DefaultShortcuts.map[.lowerRight]?.displayString == "⌃⇧⌘→")
    #expect(DefaultShortcuts.map[.redo]?.displayString == "⌥⇧⌘Z")
    #expect(DefaultShortcuts.map[.nextThird]?.displayString == "⌃⌥→")
    #expect(DefaultShortcuts.map[.previousThird]?.displayString == "⌃⌥←")
}
