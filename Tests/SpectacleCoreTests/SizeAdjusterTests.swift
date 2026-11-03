import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func makeLargerGrowsSymmetrically() {
    // centered 800×600 → +30 each dim, origin shifts −15 each
    #expect(calc(.makeLarger, CGRect(x: 320, y: 150, width: 800, height: 600)) == CGRect(x: 305, y: 135, width: 830, height: 630))
}

@Test func makeSmallerNoOpBelowQuarter() {
    // quarter of 1440×900 = 360×225 minimum; a 360×600 window is already at/under the width min → no-op
    let tiny = CGRect(x: 0, y: 0, width: 360, height: 600)
    #expect(calc(.makeSmaller, tiny) == tiny)
}

@Test func makeLargerClampsToScreen() {
    let almost = CGRect(x: 0, y: 0, width: 1430, height: 890)
    let r = calc(.makeLarger, almost)!
    #expect(r.width == 1440)
    #expect(r.height == 900)
}

@Test func makeLargerNearLeftEdgeStaysOnScreen() {
    // 6 pt from the left edge is outside the 5 pt snap distance, so the −15 shift would land at x = −9;
    // the result is shifted back inside the visible frame instead (issue #58)
    #expect(calc(.makeLarger, CGRect(x: 6, y: 150, width: 800, height: 600)) == CGRect(x: 0, y: 135, width: 830, height: 630))
}

@Test(arguments: [
    CGRect(x: 0, y: 0, width: 1440, height: 900),
    CGRect(x: 0, y: 25, width: 1440, height: 875),        // below a menu bar
    CGRect(x: 1440, y: 0, width: 1920, height: 1080),     // second display to the right
    CGRect(x: -1280, y: 200, width: 1280, height: 775),   // display to the left, offset vertically
])
func resizeStaysInsideVisibleFrameAndAboveMinimum(vf: CGRect) {
    let minW = floor(vf.width / 4), minH = floor(vf.height / 4)
    // Sizes around the minimum and the full frame; positions on, near and just past the 5 pt snap distance.
    let widths = [minW + 1, minW + 20, floor(vf.width / 2), vf.width - 40, vf.width - 12, vf.width - 6, vf.width]
    let heights = [minH + 1, minH + 20, floor(vf.height / 2), vf.height - 40, vf.height - 12, vf.height - 6, vf.height]
    let insets: [CGFloat] = [0, 3, 5, 6, 10, 14, 15, 16, 40]
    for w in widths { for h in heights {
        let xs = insets.map { vf.minX + $0 } + insets.map { vf.maxX - w - $0 } + [vf.midX - w / 2]
        let ys = insets.map { vf.minY + $0 } + insets.map { vf.maxY - h - $0 } + [vf.midY - h / 2]
        for x in xs { for y in ys {
            let win = CGRect(x: x, y: y, width: w, height: h)
            guard vf.contains(win) else { continue }
            // The adjuster ignores the gap setting; 20 checks a gap can't push the result out either.
            for action in [WindowAction.makeLarger, .makeSmaller] { for gap: CGFloat in [0, 20] {
                let input = CalculationInput(windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf, gap: gap)
                guard let r = WindowCalculator.calculate(action, input) else { Issue.record("nil for \(action) \(win)"); continue }
                #expect(vf.contains(r), "\(action) \(win) in \(vf) → \(r)")
                if r != win { #expect(r.width > minW && r.height > minH, "\(action) \(win) in \(vf) → \(r)") }
            } }
        } }
    } }
}
