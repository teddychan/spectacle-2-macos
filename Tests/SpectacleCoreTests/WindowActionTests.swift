import Testing
@testable import SpectacleCore

@Test func hasTwentyFourActions() {
    #expect(WindowAction.allCases.count == 24)
}

@Test func geometryActionsExcludeHistory() {
    #expect(!WindowAction.geometryActions.contains(.undo))
    #expect(!WindowAction.geometryActions.contains(.redo))
    #expect(WindowAction.geometryActions.count == 22)
}
