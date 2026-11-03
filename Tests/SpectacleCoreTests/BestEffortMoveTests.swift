import Testing
import CoreGraphics
@testable import SpectacleCore

// Cocoa (bottom-left origin) frames throughout. AX anchors a window at its top-left, so a window
// that refuses the requested size keeps the requested top-left and grows right and down.
private let vf = CGRect(x: 0, y: 0, width: 1440, height: 875)

@Test func widerWindowCrossingRightEdgeShiftsLeft() {
    let requested = CGRect(x: 720, y: 0, width: 720, height: 875)    // Right Half
    let actual = CGRect(x: 720, y: 0, width: 734, height: 875)       // snapped to whole columns
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: actual, visibleFrame: vf)
            == CGRect(x: 706, y: 0, width: 734, height: 875))
}

@Test func windowCrossingLeftEdgeShiftsRight() {
    let requested = CGRect(x: 0, y: 0, width: 720, height: 875)      // Left Half
    let actual = CGRect(x: -10, y: 0, width: 740, height: 875)       // app re-centered its wider frame
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: actual, visibleFrame: vf)
            == CGRect(x: 0, y: 0, width: 740, height: 875))
}

@Test func tallerWindowCrossingBottomEdgeShiftsUp() {
    let requested = CGRect(x: 0, y: 0, width: 1440, height: 437)     // Bottom Half
    let actual = CGRect(x: 0, y: -20, width: 1440, height: 457)      // same top, grew downward
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: actual, visibleFrame: vf)
            == CGRect(x: 0, y: 0, width: 1440, height: 457))
}

@Test func windowCrossingTopEdgeShiftsDown() {
    let requested = CGRect(x: 0, y: 438, width: 1440, height: 437)   // Top Half
    let actual = CGRect(x: 0, y: 430, width: 1440, height: 460)      // app kept a taller frame
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: actual, visibleFrame: vf)
            == CGRect(x: 0, y: 415, width: 1440, height: 460))
}

@Test func windowLargerThanVisibleFrameKeepsItsTopLeftOnScreen() {
    // Too big to fit either way: pin the top-left corner, where the title bar and window
    // buttons are, and let the right and bottom overflow.
    let actual = CGRect(x: 100, y: -100, width: 1500, height: 900)
    #expect(BestEffortMove.correctedFrame(requested: vf, actual: actual, visibleFrame: vf)
            == CGRect(x: 0, y: -25, width: 1500, height: 900))
}

@Test func windowLargerThanVisibleFrameAlreadyAtTopLeftStays() {
    let actual = CGRect(x: 0, y: -25, width: 1500, height: 900)      // Fullscreen, grew right and down
    #expect(BestEffortMove.correctedFrame(requested: vf, actual: actual, visibleFrame: vf) == nil)
}

@Test func windowThatAcceptedTheRectNeedsNoSecondMove() {
    let half = CGRect(x: 0, y: 0, width: 720, height: 875)
    #expect(BestEffortMove.correctedFrame(requested: half, actual: half, visibleFrame: vf) == nil)
    // Undo restoring a frame the user had dragged half off screen: restore it exactly.
    let dragged = CGRect(x: 1200, y: -100, width: 600, height: 400)
    #expect(BestEffortMove.correctedFrame(requested: dragged, actual: dragged, visibleFrame: vf) == nil)
}

@Test func correctsAgainstAScreenThatIsNotAtTheOrigin() {
    let left = CGRect(x: -1920, y: 200, width: 1920, height: 1055)  // display left of and above main
    let requested = CGRect(x: -960, y: 200, width: 960, height: 527) // Lower Right
    let actual = CGRect(x: -960, y: 190, width: 974, height: 537)    // same top, grew right and down
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: actual, visibleFrame: left)
            == CGRect(x: -974, y: 200, width: 974, height: 537))
    let pastLeft = CGRect(x: -1930, y: 400, width: 600, height: 400)
    #expect(BestEffortMove.correctedFrame(requested: requested, actual: pastLeft, visibleFrame: left)
            == CGRect(x: -1920, y: 400, width: 600, height: 400))
}
