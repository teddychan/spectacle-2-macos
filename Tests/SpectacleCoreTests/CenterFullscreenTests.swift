import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func centerKeepsSize() {
    // (1440-800)/2 = 320 ; (900-600)/2 = 150
    #expect(calc(.center, CGRect(x: 0, y: 0, width: 800, height: 600)) == CGRect(x: 320, y: 150, width: 800, height: 600))
}

@Test func fullscreenIsVisibleFrame() {
    #expect(calc(.fullscreen, CGRect(x: 10, y: 10, width: 50, height: 50)) == frame)
}

@Test func centerPinsAnOversizedWindowToTheMinEdge() {
    // #61: 1600 wide on a 1440 frame would start at x = -80. Pinned to the left edge instead; the
    // height still fits, so y stays centered: (900 - 600) / 2 = 150.
    #expect(calc(.center, CGRect(x: 0, y: 0, width: 1600, height: 600)) == CGRect(x: 0, y: 150, width: 1600, height: 600))
    // Too tall: pinned to the bottom edge, x centered: (1440 - 800) / 2 = 320.
    #expect(calc(.center, CGRect(x: 0, y: 0, width: 800, height: 1000)) == CGRect(x: 320, y: 0, width: 800, height: 1000))
    // Both, on a frame not at the origin: pinned to its left and bottom edges.
    let offset = CGRect(x: 1440, y: 25, width: 1280, height: 775)
    #expect(WindowCalculator.calculate(.center, CalculationInput(
        windowRect: CGRect(x: 1500, y: 100, width: 1300, height: 800),
        sourceVisibleFrame: offset, destinationVisibleFrame: offset))
            == CGRect(x: 1440, y: 25, width: 1300, height: 800))
}
