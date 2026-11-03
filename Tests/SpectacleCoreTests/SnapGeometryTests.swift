import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func snapLeftHalfNoGap() {
    #expect(SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func snapMaximizeNoGap() {
    #expect(SnapGeometry.rect(.maximize, visibleFrame: vf, gap: .none) == vf)
}

@Test func snapTopLeftQuarterNoGap() {
    // Cocoa top-left quarter: upper-left corner of the screen.
    #expect(SnapGeometry.rect(.topLeft, visibleFrame: vf, gap: .none)
            == CGRect(x: 0, y: 450, width: 720, height: 450))
}

@Test func snapThirdsPartitionTheWidth() {
    let first = SnapGeometry.rect(.firstThird, visibleFrame: vf, gap: .none)
    let center = SnapGeometry.rect(.centerThird, visibleFrame: vf, gap: .none)
    let last = SnapGeometry.rect(.lastThird, visibleFrame: vf, gap: .none)
    #expect(first.minX == 0)
    #expect(center.minX == first.maxX)
    #expect(last.maxX == vf.maxX)
    #expect(first.width == 480 && center.width == 480 && last.width == 480)
}

@Test func snapTwoThirdsSpanTwoColumns() {
    let firstTwo = SnapGeometry.rect(.firstTwoThirds, visibleFrame: vf, gap: .none)
    #expect(firstTwo.minX == 0 && firstTwo.width == 960)
    let lastTwo = SnapGeometry.rect(.lastTwoThirds, visibleFrame: vf, gap: .none)
    #expect(lastTwo.maxX == vf.maxX && lastTwo.width == 960)
}

@Test func snapAppliesGap() {
    // gap 10 → left half becomes the same rect WindowCalculator produces for a fresh left-half.
    let snapped = SnapGeometry.rect(.leftHalf, visibleFrame: vf, gap: WindowGap(size: 10))
    #expect(snapped == CGRect(x: 10, y: 10, width: 705, height: 880))
}

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)   // Cocoa: minY bottom, maxY top

@Test func zoneNilInInterior() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 450), in: screen) == nil)
}
@Test func zoneTopEdge() {
    // near maxY (top), away from corners → .top
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 898), in: screen) == .top)
}
@Test func zoneBottomEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 700, y: 2), in: screen) == .bottom)
}
@Test func zoneLeftEdge() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 2, y: 450), in: screen) == .left)
}
@Test func zoneCornerTopLeftWins() {
    // within 25pt of both the left and the top → corner, not edge
    #expect(SnapGeometry.zone(for: CGPoint(x: 3, y: 890), in: screen) == .topLeft)
}
@Test func zoneCornerBottomRight() {
    #expect(SnapGeometry.zone(for: CGPoint(x: 1438, y: 3), in: screen) == .bottomRight)
}

@Test func sideHalfNearTopCorner() {
    // On the left edge within 145pt of the top → top half; middle → nil (plain left half)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 850, in: screen) == .topHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 50, in: screen) == .bottomHalf)
    #expect(SnapGeometry.sideEdgeHalf(cursorY: 450, in: screen) == nil)
}

@Test func bottomEdgeThirdByCursorX() {
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 100, in: screen) == .first)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 720, in: screen) == .center)
    #expect(SnapGeometry.bottomEdgeThird(cursorX: 1400, in: screen) == .last)
}

// bottom-zone cursor points, one per column (see zoneBottomEdge / bottomEdgeThirdByCursorX above).
private let bottomFirstX = CGPoint(x: 100, y: 2)
private let bottomCenterX = CGPoint(x: 720, y: 2)
private let bottomLastX = CGPoint(x: 1400, y: 2)

@Test func targetPromotesFirstThirdToTwoThirds() {
    // Entering the center third right after the first third widens the tile to two-thirds.
    let result = SnapGeometry.target(for: .bottom, cursor: bottomCenterX, screen: screen, previousBottomColumn: .first)
    #expect(result.target == .firstTwoThirds)
}

@Test func targetPromotesLastThirdToTwoThirds() {
    let result = SnapGeometry.target(for: .bottom, cursor: bottomCenterX, screen: screen, previousBottomColumn: .last)
    #expect(result.target == .lastTwoThirds)
}

@Test func targetColdCenterDoesNotPromote() {
    // No previous bottom column (fresh drag) → plain center third, no promotion.
    let result = SnapGeometry.target(for: .bottom, cursor: bottomCenterX, screen: screen, previousBottomColumn: nil)
    #expect(result.target == .centerThird)
}

@Test func targetPlainThirds() {
    #expect(SnapGeometry.target(for: .bottom, cursor: bottomFirstX, screen: screen, previousBottomColumn: nil).target == .firstThird)
    #expect(SnapGeometry.target(for: .bottom, cursor: bottomLastX, screen: screen, previousBottomColumn: nil).target == .lastThird)
}

@Test func targetBottomZoneAlwaysRefreshesColumn() {
    // The returned column is the freshly computed one for `.bottom`, regardless of promotion.
    let result = SnapGeometry.target(for: .bottom, cursor: bottomFirstX, screen: screen, previousBottomColumn: .last)
    #expect(result.bottomColumn == .first)
}

@Test func targetNonBottomZoneLeavesColumnUntouched() {
    // The subtle invariant: only `.bottom` may update the column. Every other zone must return
    // `previousBottomColumn` unchanged, since the caller unconditionally stores the result back.
    let cursor = CGPoint(x: 700, y: 898)   // top edge
    let result = SnapGeometry.target(for: .top, cursor: cursor, screen: screen, previousBottomColumn: .first)
    #expect(result.bottomColumn == .first)
    let result2 = SnapGeometry.target(for: .top, cursor: cursor, screen: screen, previousBottomColumn: nil)
    #expect(result2.bottomColumn == nil)
}

@Test func targetTopIsMaximizeAndCornerMapsThrough() {
    let cursor = CGPoint(x: 700, y: 898)
    #expect(SnapGeometry.target(for: .top, cursor: cursor, screen: screen, previousBottomColumn: nil).target == .maximize)
    #expect(SnapGeometry.target(for: .topLeft, cursor: cursor, screen: screen, previousBottomColumn: nil).target == .topLeft)
}

@Test func targetLeftZonePromotesToTopHalfNearTop() {
    let nearTop = CGPoint(x: 2, y: 850)
    #expect(SnapGeometry.target(for: .left, cursor: nearTop, screen: screen, previousBottomColumn: nil).target == .topHalf)
    let midScreen = CGPoint(x: 2, y: 450)
    #expect(SnapGeometry.target(for: .left, cursor: midScreen, screen: screen, previousBottomColumn: nil).target == .leftHalf)
}

// MARK: Snapped tiles match the keyboard tiles (#67, #68)

@Test func snapSkipTopKeepsAFullGapBetweenStackedWindows() {
    // gap 10, skipTop: stacked halves and corners are 10 apart, and the upper ones reach maxY 900.
    let g = WindowGap(size: 10, skipTopEdge: true)
    for (upper, lower) in [(SnapTarget.topHalf, SnapTarget.bottomHalf), (.topLeft, .bottomLeft), (.topRight, .bottomRight)] {
        let u = SnapGeometry.rect(upper, visibleFrame: vf, gap: g)
        let l = SnapGeometry.rect(lower, visibleFrame: vf, gap: g)
        #expect(u.minY - l.maxY == 10, "\(upper) / \(lower)")
        #expect(u.maxY == vf.maxY, "\(upper)")
    }
}

/// The keyboard result for `a` on `screen`, from `win` or else a small window that does not cycle.
private func keyboard(_ a: WindowAction, _ screen: CGRect, _ g: WindowGap, from win: CGRect? = nil) -> CGRect {
    WindowCalculator.calculate(a, CalculationInput(
        windowRect: win ?? CGRect(x: screen.minX, y: screen.minY, width: 10, height: 10),
        sourceVisibleFrame: screen, destinationVisibleFrame: screen,
        gap: g.size, skipGapTopEdge: g.skipTopEdge))!
}

// Odd sizes, and a screen above and left of the main one.
private let snapScreens = [vf, CGRect(x: 0, y: 0, width: 1441, height: 875),
                           CGRect(x: -1280, y: 900, width: 1279, height: 777)]

@Test func snapMatchesKeyboardTiles() {
    let pairs: [(SnapTarget, WindowAction)] = [
        (.leftHalf, .leftHalf), (.rightHalf, .rightHalf), (.topHalf, .topHalf), (.bottomHalf, .bottomHalf),
        (.topLeft, .upperLeft), (.topRight, .upperRight), (.bottomLeft, .lowerLeft), (.bottomRight, .lowerRight),
        (.maximize, .fullscreen),
    ]
    for screen in snapScreens {
        for size: CGFloat in [0, 4, 10, 30] {
            for skipTop in [false, true] {
                let g = WindowGap(size: size, skipTopEdge: skipTop)
                for (target, action) in pairs {
                    #expect(SnapGeometry.rect(target, visibleFrame: screen, gap: g) == keyboard(action, screen, g),
                            "\(target) \(screen) \(g)")
                }
                // Next Third from a fresh window visits the first, center and last column in turn.
                let first = keyboard(.nextThird, screen, g)
                let center = keyboard(.nextThird, screen, g, from: first)
                let last = keyboard(.nextThird, screen, g, from: center)
                #expect(SnapGeometry.rect(.firstThird, visibleFrame: screen, gap: g) == first, "\(screen) \(g)")
                #expect(SnapGeometry.rect(.centerThird, visibleFrame: screen, gap: g) == center, "\(screen) \(g)")
                #expect(SnapGeometry.rect(.lastThird, visibleFrame: screen, gap: g) == last, "\(screen) \(g)")
                // Two-thirds equal the ⅔ step of Left Half and Right Half (#70).
                let leftTwo = keyboard(.leftHalf, screen, g, from: keyboard(.leftHalf, screen, g))
                let rightTwo = keyboard(.rightHalf, screen, g, from: keyboard(.rightHalf, screen, g))
                #expect(SnapGeometry.rect(.firstTwoThirds, visibleFrame: screen, gap: g) == leftTwo, "\(screen) \(g)")
                #expect(SnapGeometry.rect(.lastTwoThirds, visibleFrame: screen, gap: g) == rightTwo, "\(screen) \(g)")
            }
        }
    }
}

@Test func snapThirdsAreAGapApartOnOddWidths() {
    // Working widths 1441, 1430, 1438 and 1277 leave 1, 2, 1 and 2 over after dividing by 3.
    let cases: [(CGRect, CGFloat)] = [(CGRect(x: 0, y: 0, width: 1441, height: 900), 0), (vf, 10), (vf, 2),
                                      (CGRect(x: -1280, y: 900, width: 1279, height: 777), 2)]
    for (screen, size) in cases {
        func r(_ t: SnapTarget) -> CGRect { SnapGeometry.rect(t, visibleFrame: screen, gap: WindowGap(size: size)) }
        #expect(r(.firstThird).minX - screen.minX == size, "\(screen) \(size)")
        #expect(r(.centerThird).minX - r(.firstThird).maxX == size, "\(screen) \(size)")
        #expect(r(.lastThird).minX - r(.centerThird).maxX == size, "\(screen) \(size)")
        #expect(screen.maxX - r(.lastThird).maxX == size, "\(screen) \(size)")
        // A two-thirds tile sits beside the opposite third the same way.
        #expect(r(.lastThird).minX - r(.firstTwoThirds).maxX == size, "\(screen) \(size)")
        #expect(r(.lastTwoThirds).minX - r(.firstThird).maxX == size, "\(screen) \(size)")
    }
}
