import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func leftHalfBase() {
    #expect(calc(.leftHalf, CGRect(x: 200, y: 100, width: 400, height: 300)) == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func leftHalfCyclesHalfTwoThirdOneThird() {
    let half = CGRect(x: 0, y: 0, width: 720, height: 900)
    let twoThird = calc(.leftHalf, half)
    #expect(twoThird == CGRect(x: 0, y: 0, width: 960, height: 900))
    let oneThird = calc(.leftHalf, twoThird!)
    #expect(oneThird == CGRect(x: 0, y: 0, width: 480, height: 900))
    let backToHalf = calc(.leftHalf, oneThird!)
    #expect(backToHalf == half)
}

@Test func rightHalfBaseAndCycle() {
    #expect(calc(.rightHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 720, y: 0, width: 720, height: 900))
    let half = CGRect(x: 720, y: 0, width: 720, height: 900)
    #expect(calc(.rightHalf, half) == CGRect(x: 480, y: 0, width: 960, height: 900)) // ⅔ right-aligned
}

@Test func topAndBottomHalfBase() {
    // top uses larger y (Cocoa bottom-left): y = 0 + 450 + (900 % 2 == 0) = 450
    #expect(calc(.topHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 0, y: 450, width: 1440, height: 450))
    #expect(calc(.bottomHalf, CGRect(x: 0, y: 0, width: 10, height: 10)) == CGRect(x: 0, y: 0, width: 1440, height: 450))
}

// MARK: Odd sizes and the thirds columns (#70)

// Odd and even sizes, and a screen below and left of the main one.
private let screens = [CGRect(x: 0, y: 0, width: 1441, height: 875), CGRect(x: 0, y: 0, width: 1366, height: 767),
                       frame, CGRect(x: -1279, y: -799, width: 1279, height: 799)]

/// Press `a` `n` times from `start` (else a small window that matches no half or corner), returning each result.
private func presses(_ a: WindowAction, _ n: Int, _ screen: CGRect, gap: CGFloat, skipTop: Bool = false,
                     from start: CGRect? = nil) -> [CGRect] {
    var win = start ?? CGRect(x: screen.minX, y: screen.minY, width: 10, height: 10)
    return (0..<n).map { _ in
        win = WindowCalculator.calculate(a, CalculationInput(
            windowRect: win, sourceVisibleFrame: screen, destinationVisibleFrame: screen,
            gap: gap, skipGapTopEdge: skipTop))!
        return win
    }
}

@Test func halvesAndCornersLeaveTheGapAsTheOuterMarginOnEverySide() {
    for screen in screens {
        for gap: CGFloat in [0, 10, 14] {
            func one(_ a: WindowAction) -> CGRect { presses(a, 1, screen, gap: gap)[0] }
            let (l, r, t, b) = (one(.leftHalf), one(.rightHalf), one(.topHalf), one(.bottomHalf))
            let (ul, ur, ll, lr) = (one(.upperLeft), one(.upperRight), one(.lowerLeft), one(.lowerRight))
            let ctx = "\(screen) gap \(gap)"
            for w in [l, ul, ll] { #expect(w.minX - screen.minX == gap, "\(ctx) \(w)") }
            for w in [r, ur, lr] { #expect(screen.maxX - w.maxX == gap, "\(ctx) \(w)") }
            for w in [t, ul, ur] { #expect(screen.maxY - w.maxY == gap, "\(ctx) \(w)") }
            for w in [b, ll, lr] { #expect(w.minY - screen.minY == gap, "\(ctx) \(w)") }
            for w in [l, r] { #expect(w.minY - screen.minY == gap && screen.maxY - w.maxY == gap, "\(ctx) \(w)") }
            for w in [t, b] { #expect(w.minX - screen.minX == gap && screen.maxX - w.maxX == gap, "\(ctx) \(w)") }
            // Neighbours sit exactly one gap apart.
            #expect(r.minX - l.maxX == gap && ur.minX - ul.maxX == gap && lr.minX - ll.maxX == gap, "\(ctx)")
            #expect(t.minY - b.maxY == gap && ul.minY - ll.maxY == gap && ur.minY - lr.maxY == gap, "\(ctx)")
        }
    }
}

@Test func twoThirdAndOneThirdStepsLineUpWithTheThirdsColumns() {
    for screen in screens {
        for gap: CGFloat in [0, 10, 14] {
            for skipTop in [false, true] {
                let t = presses(.nextThird, 6, screen, gap: gap, skipTop: skipTop)
                let (cols, rows) = (Array(t[0..<3]), Array(t[3..<6]))
                let ctx = "\(screen) gap \(gap) skipTop \(skipTop)"
                // ½ → ⅔ → ⅓ → ½, with each ⅔ spanning two columns (or rows) and each ⅓ on one.
                func cycle(_ a: WindowAction) -> [CGRect] {
                    let r = presses(a, 4, screen, gap: gap, skipTop: skipTop)
                    #expect(r[3] == r[0] && Set(r.map { "\($0)" }).count == 3, "\(a) \(ctx): \(r)")
                    return r
                }
                func xs(_ r: CGRect) -> [CGFloat] { [r.minX, r.maxX] }
                func ys(_ r: CGRect) -> [CGFloat] { [r.minY, r.maxY] }
                for a: WindowAction in [.leftHalf, .upperLeft, .lowerLeft] {
                    let r = cycle(a)
                    #expect(xs(r[1]) == [cols[0].minX, cols[1].maxX] && xs(r[2]) == xs(cols[0]), "\(a) \(ctx): \(r)")
                    // A ⅔ Left Half sits one gap from the third column.
                    #expect(cols[2].minX - r[1].maxX == gap, "\(a) \(ctx)")
                }
                for a: WindowAction in [.rightHalf, .upperRight, .lowerRight] {
                    let r = cycle(a)
                    #expect(xs(r[1]) == [cols[1].minX, cols[2].maxX] && xs(r[2]) == xs(cols[2]), "\(a) \(ctx): \(r)")
                    #expect(r[1].minX - cols[0].maxX == gap, "\(a) \(ctx)")
                }
                let top = cycle(.topHalf)
                #expect(ys(top[1]) == [rows[1].minY, rows[0].maxY] && ys(top[2]) == ys(rows[0]), "\(ctx): \(top)")
                let bottom = cycle(.bottomHalf)
                #expect(ys(bottom[1]) == [rows[2].minY, rows[1].maxY] && ys(bottom[2]) == ys(rows[2]), "\(ctx): \(bottom)")
            }
        }
    }
}

@Test func halvesOnAnOddScreenGiveTheOddPointsToATile() {
    // 1441 = 2 × 720 + 1 = 3 × 480 + 1 and 875 = 2 × 437 + 1 = 3 × 291 + 2. The right half and the
    // bottom half take the odd point; the ⅔ and ⅓ steps end on the thirds columns and rows
    // (455 + 480 = 960 wide on the right, rows 291, 291 and 293 high from the top).
    let s = screens[0]
    #expect(presses(.leftHalf, 3, s, gap: 0) == [CGRect(x: 0, y: 0, width: 720, height: 875),
                                                  CGRect(x: 0, y: 0, width: 960, height: 875),
                                                  CGRect(x: 0, y: 0, width: 480, height: 875)])
    #expect(presses(.rightHalf, 3, s, gap: 0) == [CGRect(x: 720, y: 0, width: 721, height: 875),
                                                   CGRect(x: 480, y: 0, width: 961, height: 875),
                                                   CGRect(x: 960, y: 0, width: 481, height: 875)])
    #expect(presses(.topHalf, 3, s, gap: 0) == [CGRect(x: 0, y: 438, width: 1441, height: 437),
                                                 CGRect(x: 0, y: 293, width: 1441, height: 582),
                                                 CGRect(x: 0, y: 584, width: 1441, height: 291)])
    #expect(presses(.bottomHalf, 3, s, gap: 0) == [CGRect(x: 0, y: 0, width: 1441, height: 438),
                                                    CGRect(x: 0, y: 0, width: 1441, height: 584),
                                                    CGRect(x: 0, y: 0, width: 1441, height: 293)])
    #expect(presses(.lowerRight, 3, s, gap: 0) == [CGRect(x: 720, y: 0, width: 721, height: 438),
                                                    CGRect(x: 480, y: 0, width: 961, height: 438),
                                                    CGRect(x: 960, y: 0, width: 481, height: 438)])
}

@Test func cyclingStillAdvancesFromAWindowPlacedByTheOldRounding() {
    // Windows tiled before #70 on 1441×875 at gap 0: the right half, bottom half and lower-right
    // quarter were 1 pt short, and the right ⅔ was floor(2 × 1441 / 3) = 960 wide. Each sits inside
    // the new, wider step with its center within 1 pt, so the next press still advances.
    let s = screens[0]
    #expect(presses(.rightHalf, 1, s, gap: 0, from: CGRect(x: 720, y: 0, width: 720, height: 875))
            == [CGRect(x: 480, y: 0, width: 961, height: 875)])
    #expect(presses(.rightHalf, 1, s, gap: 0, from: CGRect(x: 481, y: 0, width: 960, height: 875))
            == [CGRect(x: 960, y: 0, width: 481, height: 875)])
    #expect(presses(.bottomHalf, 1, s, gap: 0, from: CGRect(x: 0, y: 0, width: 1441, height: 437))
            == [CGRect(x: 0, y: 0, width: 1441, height: 584)])
    #expect(presses(.lowerRight, 1, s, gap: 0, from: CGRect(x: 720, y: 0, width: 720, height: 437))
            == [CGRect(x: 480, y: 0, width: 961, height: 438)])
}
