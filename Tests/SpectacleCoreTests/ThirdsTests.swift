import Testing
import CoreGraphics
@testable import SpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)   // ⅓ w = 480, ⅓ h = 300
private func calc(_ a: WindowAction, _ win: CGRect) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(windowRect: win, sourceVisibleFrame: frame, destinationVisibleFrame: frame))
}

@Test func uncenteredDefaultsToLeftColumn() {
    #expect(calc(.nextThird, CGRect(x: 5, y: 5, width: 100, height: 100)) == CGRect(x: 0, y: 0, width: 480, height: 900))
}

@Test func nextThirdCyclesColumnsThenRows() {
    let leftCol = CGRect(x: 0, y: 0, width: 480, height: 900)
    let midCol = calc(.nextThird, leftCol)
    #expect(midCol == CGRect(x: 480, y: 0, width: 480, height: 900))
    let rightCol = calc(.nextThird, midCol!)
    #expect(rightCol == CGRect(x: 960, y: 0, width: 480, height: 900))
    let topRow = calc(.nextThird, rightCol!)   // regions[3]: top row, y = 900 - 300 = 600
    #expect(topRow == CGRect(x: 0, y: 600, width: 1440, height: 300))
}

@Test func previousThirdWrapsBackward() {
    let leftCol = CGRect(x: 0, y: 0, width: 480, height: 900)
    // previous of regions[0] wraps to regions[5] = bottom row (y = 900 - 300*3 = 0)
    #expect(calc(.previousThird, leftCol) == CGRect(x: 0, y: 0, width: 1440, height: 300))
}

/// The six thirds in Next Third order: three columns, then the top, middle and bottom rows.
private func sixThirds(_ screen: CGRect, gap: CGFloat, skipTop: Bool = false) -> [CGRect] {
    var win = CGRect(x: screen.minX, y: screen.minY, width: 10, height: 10)
    return (0..<6).map { _ in
        win = WindowCalculator.calculate(.nextThird, CalculationInput(
            windowRect: win, sourceVisibleFrame: screen, destinationVisibleFrame: screen,
            gap: gap, skipGapTopEdge: skipTop))!
        return win
    }
}

@Test func thirdsLeaveTheGapAsTheOuterMarginOnEverySide() {
    // #64: the rounding remainder used to land in the right and bottom margins (12 and 11 pt at
    // gap 10 on 1440×900, whose working frame is 1430×890). Odd sizes leave a remainder of 1 or 2.
    let screens = [frame, CGRect(x: 0, y: 0, width: 1366, height: 875),
                   CGRect(x: -1279, y: 900, width: 1279, height: 799),
                   CGRect(x: 1440, y: 25, width: 2560, height: 1415)]
    for screen in screens {
        for gap in [CGFloat(0), 10, 14, 20] {
            let t = sixThirds(screen, gap: gap)
            let ctx = "\(screen) gap \(gap): \(t)"
            let (cols, rows) = (t[0..<3], t[3..<6])
            #expect(t[0].minX - screen.minX == gap && screen.maxX - t[2].maxX == gap, "\(ctx)")
            #expect(screen.maxY - t[3].maxY == gap && t[5].minY - screen.minY == gap, "\(ctx)")
            #expect(cols.allSatisfy { $0.minY - screen.minY == gap && screen.maxY - $0.maxY == gap }, "\(ctx)")
            #expect(rows.allSatisfy { $0.minX - screen.minX == gap && screen.maxX - $0.maxX == gap }, "\(ctx)")
            // Neighbours sit exactly one gap apart.
            #expect(t[1].minX - t[0].maxX == gap && t[2].minX - t[1].maxX == gap, "\(ctx)")
            #expect(t[3].minY - t[4].maxY == gap && t[4].minY - t[5].maxY == gap, "\(ctx)")
        }
    }
}

@Test func thirdsGiveTheRemainderToTheLastColumnAndBottomRow() {
    // 1366 = 3 × 455 + 1 and 875 = 3 × 291 + 2. The original floored every third and left the
    // remainder uncovered at the right and bottom edges; now the right column and the bottom row
    // take it, and the other four thirds are unchanged.
    #expect(sixThirds(CGRect(x: 0, y: 0, width: 1366, height: 875), gap: 0) == [
        CGRect(x: 0, y: 0, width: 455, height: 875),
        CGRect(x: 455, y: 0, width: 455, height: 875),
        CGRect(x: 910, y: 0, width: 456, height: 875),
        CGRect(x: 0, y: 584, width: 1366, height: 291),
        CGRect(x: 0, y: 293, width: 1366, height: 291),
        CGRect(x: 0, y: 0, width: 1366, height: 293),
    ])
}
