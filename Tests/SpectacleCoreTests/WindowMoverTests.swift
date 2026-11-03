import Testing
import CoreGraphics
@testable import SpectacleCore

// The whole move a keyboard action or a snap makes, against a simulated app. Cocoa frames.
private let vf = CGRect(x: 0, y: 0, width: 1440, height: 875)
private let rightHalf = CGRect(x: 720, y: 0, width: 720, height: 875)

private func move(_ window: SimulatedWindow, to requested: CGRect) {
    WindowMover.move(to: requested, visibleFrame: vf,
                     setFrame: window.setFrame, frame: { window.frame })
}

@Test func windowThatAcceptsAnySizeTakesOneWrite() {
    let window = SimulatedWindow(CGRect(x: 300, y: 200, width: 500, height: 400))
    move(window, to: rightHalf)
    #expect(window.writes == [rightHalf])
    #expect(window.frame == rightHalf)
}

@Test func windowWithAMinimumSizeGivesUpEarlyThenEndsOnScreen() {
    let window = SimulatedWindow(CGRect(x: 300, y: 200, width: 500, height: 400),
                                 size: SimulatedWindow.minimum(CGSize(width: 1000, height: 0)))
    move(window, to: rightHalf)
    // Standard write, 16 quantized steps (718 … 688) that the window ignores, the centring write
    // at x 580, then the best-effort write pulling the 1000-wide window back inside the right edge.
    #expect(window.writes.count == 19)
    #expect(window.writes.map(\.width).min() == 688)
    #expect(window.frame == CGRect(x: 440, y: 0, width: 1000, height: 875))
}

@Test func terminalsTiledLeftAndRightDoNotOverlap() {
    let cells = SimulatedWindow.cells(CGSize(width: 7, height: 14))
    let left = SimulatedWindow(.zero, size: cells), right = SimulatedWindow(.zero, size: cells)
    move(left, to: CGRect(x: 0, y: 0, width: 720, height: 875))
    move(right, to: rightHalf)
    #expect(left.frame.maxX <= right.frame.minX)
    #expect(left.frame == CGRect(x: 3, y: 4, width: 714, height: 868))
    #expect(right.frame == CGRect(x: 723, y: 4, width: 714, height: 868))
}
