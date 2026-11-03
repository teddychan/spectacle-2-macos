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

@Test func windowWithAMinimumSizeEndsOnScreen() {
    let window = SimulatedWindow(CGRect(x: 300, y: 200, width: 500, height: 400),
                                 size: SimulatedWindow.minimum(CGSize(width: 1000, height: 0)))
    move(window, to: rightHalf)
    #expect(window.frame == CGRect(x: 440, y: 0, width: 1000, height: 875))
}
