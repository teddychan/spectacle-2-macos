import Testing
import CoreGraphics
@testable import SpectacleCore

private let vf = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func gapInsetZeroIsIdentity() {
    #expect(WindowGap.inset(vf, half: 0, skipTop: false) == vf)
}

@Test func gapInsetShrinksAllEdgesByHalf() {
    // half = 5 → 5pt off left, right, top and bottom.
    #expect(WindowGap.inset(vf, half: 5, skipTop: false)
            == CGRect(x: 5, y: 5, width: 1430, height: 890))
}

@Test func gapInsetSkipTopLeavesTopEdge() {
    // Cocoa coords: top edge is maxY. skipTop must not shrink the top → height loses only the
    // bottom 5pt, origin.y rises 5pt, maxY stays at 900.
    let r = WindowGap.inset(vf, half: 5, skipTop: true)
    #expect(r == CGRect(x: 5, y: 5, width: 1430, height: 895))
    #expect(r.maxY == vf.maxY)
}

@Test func gapOutsetUndoesInset() {
    #expect(WindowGap.outset(CGRect(x: 5, y: 5, width: 1430, height: 890), half: 5, skipTop: false) == vf)
    #expect(WindowGap.outset(CGRect(x: 5, y: 5, width: 1430, height: 895), half: 5, skipTop: true) == vf)
    #expect(WindowGap.outset(vf, half: 0, skipTop: true) == vf)
}

private func calcGap(_ a: WindowAction, _ win: CGRect, gap: CGFloat, skipTop: Bool = false) -> CGRect? {
    WindowCalculator.calculate(a, CalculationInput(
        windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf,
        gap: gap, skipGapTopEdge: skipTop))
}

@Test func gapZeroMatchesUngapped() {
    // Regression guard: gap 0 reproduces the classic left-half exactly.
    #expect(calcGap(.leftHalf, CGRect(x: 200, y: 100, width: 400, height: 300), gap: 0)
            == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func gapLeftHalfHasOuterAndInnerGap() {
    // gap 10 → half=5. Working frame = vf inset 5 = (5,5,1430,890); left half width floor(1430/2)=715
    // at x=5; then inset 5 → (10,10,705,880). Right edge = 715, i.e. 5 short of vf.midX (720).
    let left = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(left == CGRect(x: 10, y: 10, width: 705, height: 880))
    // Right half mirrors: left edge 10pt past the midline → 10pt gap between the two halves.
    let right = calcGap(.rightHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)
    #expect(right?.minX == 725)          // 720 (working right-half x = 5 + 715) + 5 (its own inset)
}

@Test func gapFullscreenLeavesUniformMargin() {
    // gap 20 → full-G (20pt) margin on every edge, so a maximized window sits the same 20pt off
    // the screen as a half-window's outer edge. vf inset by half twice = 10+10 = 20 all round.
    #expect(calcGap(.fullscreen, .zero, gap: 20) == CGRect(x: 20, y: 20, width: 1400, height: 860))
}

@Test func gapDoesNotAffectCenter() {
    // Center preserves size and centers within the TRUE visible frame regardless of gap.
    let win = CGRect(x: 0, y: 0, width: 400, height: 300)
    #expect(calcGap(.center, win, gap: 40) == WindowCalculator.calculate(.center,
        CalculationInput(windowRect: win, sourceVisibleFrame: vf, destinationVisibleFrame: vf)))
}

@Test func gapCyclingStillAdvances() {
    // A gapped left-half, pressed again, must still advance to the (gapped) two-thirds.
    let half = calcGap(.leftHalf, CGRect(x: 0, y: 0, width: 100, height: 100), gap: 10)!
    let twoThird = calcGap(.leftHalf, half, gap: 10)!
    #expect(twoThird.width > half.width)   // advanced, not stuck
}

@Test func gapSkipTopEdgeOnFullscreen() {
    // skipTop → no gap at maxY; other three edges still gapped by 20.
    let r = calcGap(.fullscreen, .zero, gap: 20, skipTop: true)!
    #expect(r.maxY == vf.maxY)
    #expect(r.minX == 20 && r.minY == 20 && r.maxX == 1420)
}

// MARK: Cycling with the top-edge gap skipped (#57)

/// Press `a` `n` times starting from `start` on visible frame `screen`, returning each result.
private func presses(_ a: WindowAction, from start: CGRect, _ n: Int, screen: CGRect = vf,
                     gap: CGFloat, skipTop: Bool) -> [CGRect] {
    var win = start
    var out: [CGRect] = []
    for _ in 0..<n {
        win = WindowCalculator.calculate(a, CalculationInput(
            windowRect: win, sourceVisibleFrame: screen, destinationVisibleFrame: screen,
            gap: gap, skipGapTopEdge: skipTop))!
        out.append(win)
    }
    return out
}

private let offAxis = CGRect(x: 0, y: 0, width: 10, height: 10)

@Test func gapSkipTopLeftHalfCycles() {
    // gap 10, skipTop → working frame (5,5,1430,890); ½ = 715, ⅔ = 2 × 476 = 952 (two thirds columns),
    // ⅓ = 476 wide, each then inset 5 on left/right/bottom and grown to the top of the screen, so the
    // window keeps maxY = 900.
    #expect(presses(.leftHalf, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 10, width: 705, height: 890),
        CGRect(x: 10, y: 10, width: 942, height: 890),
        CGRect(x: 10, y: 10, width: 466, height: 890),
        CGRect(x: 10, y: 10, width: 705, height: 890),
    ])
}

@Test func gapSkipTopTopHalfCycles() {
    // Height cycle: ½ = 445 (bottom at 5 + 445 = 450), ⅔ = 2 × 296 = 592 (two thirds rows), ⅓ = 296,
    // all top-aligned at 900.
    #expect(presses(.topHalf, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 455, width: 1420, height: 445),
        CGRect(x: 10, y: 308, width: 1420, height: 592),
        CGRect(x: 10, y: 604, width: 1420, height: 296),
        CGRect(x: 10, y: 455, width: 1420, height: 445),
    ])
}

@Test func gapSkipTopCornersCycle() {
    #expect(presses(.upperLeft, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 455, width: 705, height: 445),
        CGRect(x: 10, y: 455, width: 942, height: 445),
        CGRect(x: 10, y: 455, width: 466, height: 445),
        CGRect(x: 10, y: 455, width: 705, height: 445),
    ])
    // On the thirds columns at x = 481 and 957, which run to the working frame's maxX 1435: ⅔ = 954
    // and ⅓ = 478 wide. Not at the top, so the top edge keeps its gap and ends at 450 - 5 = 445, 10
    // below the upper corners.
    #expect(presses(.lowerRight, from: CGRect(x: 0, y: 890, width: 10, height: 10), 4,
                    gap: 10, skipTop: true) == [
        CGRect(x: 725, y: 10, width: 705, height: 435),
        CGRect(x: 486, y: 10, width: 944, height: 435),
        CGRect(x: 962, y: 10, width: 468, height: 435),
        CGRect(x: 725, y: 10, width: 705, height: 435),
    ])
}

@Test func gapSkipTopThirdsCycle() {
    // Columns 476 wide at x = 5, 481, 957 (the last 478, to the frame's edge); rows 296 high at
    // y = 599, 303 and 298 high at 5; each inset 5, with the columns and top row grown to y = 900.
    let cols = [CGRect(x: 10, y: 10, width: 466, height: 890),
                CGRect(x: 486, y: 10, width: 466, height: 890),
                CGRect(x: 962, y: 10, width: 468, height: 890)]
    let rows = [CGRect(x: 10, y: 604, width: 1420, height: 296),
                CGRect(x: 10, y: 308, width: 1420, height: 286),
                CGRect(x: 10, y: 10, width: 1420, height: 288)]
    #expect(presses(.nextThird, from: offAxis, 7, gap: 10, skipTop: true)
            == cols + rows + [cols[0]])
    #expect(presses(.previousThird, from: cols[0], 3, gap: 10, skipTop: true)
            == [rows[2], rows[1], rows[0]])
}

@Test func gapSkipTopCyclesOnOffsetScreenWithMenuBar() {
    // A second display right of the first (x = 1440) with a 25pt menu bar: visible (1440,0,1440,875),
    // working frame (1445,5,1430,870). Goes through the resolver, as the app does.
    let screen = CGRect(x: 1440, y: 0, width: 1440, height: 875)
    var history = WindowHistory()
    var win = CGRect(x: 1600, y: 100, width: 300, height: 200)
    var got: [CGRect] = []
    for _ in 0..<4 {
        let outcome = WindowActionResolver.resolve(
            action: .leftHalf, windowID: 1, currentFrame: win,
            sourceVisibleFrame: screen, destinationVisibleFrame: screen,
            gap: 10, skipGapTopEdge: true, history: &history)
        guard case .move(let r) = outcome else { Issue.record("expected a move"); return }
        win = r; got.append(r)
    }
    #expect(got == [
        CGRect(x: 1450, y: 10, width: 705, height: 865),
        CGRect(x: 1450, y: 10, width: 942, height: 865),
        CGRect(x: 1450, y: 10, width: 466, height: 865),
        CGRect(x: 1450, y: 10, width: 705, height: 865),
    ])
    // Next Third from the first column moves to the second (x = 1445 + 476 + 5).
    #expect(presses(.nextThird, from: CGRect(x: 1450, y: 10, width: 466, height: 865), 1,
                    screen: screen, gap: 10, skipTop: true)
            == [CGRect(x: 1926, y: 10, width: 466, height: 865)])
}

// MARK: Only the top edge skips its gap (#63)

/// The space between each stacked pair: top/bottom halves, upper/lower corners (left and right),
/// and the top/middle and middle/bottom thirds rows.
private func stackedGaps(_ screen: CGRect, gap: CGFloat, skipTop: Bool) -> [CGFloat] {
    func one(_ a: WindowAction) -> CGRect { presses(a, from: offAxis, 1, screen: screen, gap: gap, skipTop: skipTop)[0] }
    let rows = presses(.nextThird, from: CGRect(x: screen.minX, y: screen.minY, width: 466, height: 10), 6,
                       screen: screen, gap: gap, skipTop: skipTop)
    return [one(.topHalf).minY - one(.bottomHalf).maxY,
            one(.upperLeft).minY - one(.lowerLeft).maxY,
            one(.upperRight).minY - one(.lowerRight).maxY,
            rows[3].minY - rows[4].maxY, rows[4].minY - rows[5].maxY]
}

@Test func gapSkipTopKeepsAFullGapBetweenStackedWindows() {
    // gap 10 on 1440×900: every stacked pair is 10 apart, while the windows on top reach maxY 900.
    #expect(stackedGaps(vf, gap: 10, skipTop: true) == [10, 10, 10, 10, 10])
    for a: WindowAction in [.topHalf, .upperLeft, .upperRight, .leftHalf, .rightHalf, .fullscreen] {
        #expect(presses(a, from: offAxis, 1, gap: 10, skipTop: true)[0].maxY == vf.maxY, "\(a)")
    }
    // The three columns and the top row.
    #expect(presses(.nextThird, from: offAxis, 4, gap: 10, skipTop: true).allSatisfy { $0.maxY == vf.maxY })
    // Below the top edge nothing changes: the bottom half and lower corners match the gapped
    // layout with the top gap on.
    for a: WindowAction in [.bottomHalf, .lowerLeft, .lowerRight] {
        #expect(presses(a, from: offAxis, 1, gap: 10, skipTop: true)
                == presses(a, from: offAxis, 1, gap: 10, skipTop: false), "\(a)")
    }
    // Stacked windows sit as far apart as with the top gap on, for every gap and odd sizes too.
    for screen in [vf, CGRect(x: 0, y: 0, width: 1366, height: 875), CGRect(x: -1280, y: 900, width: 1280, height: 777)] {
        for gap in stride(from: CGFloat(0), through: 100, by: 2) {
            #expect(stackedGaps(screen, gap: gap, skipTop: true) == stackedGaps(screen, gap: gap, skipTop: false),
                    "\(screen) gap \(gap)")
        }
    }
}

@Test func cyclingAdvancesTheSameForEveryGapSetting() {
    // Every gap the stepper offers (0…100 step 2), with and without skipTop, on a screen above and
    // left of the main one: halves and corners visit 3 distinct rects then wrap; thirds visit 6.
    let screen = CGRect(x: -1280, y: 900, width: 1280, height: 777)
    let cycles: [(WindowAction, Int)] = [
        (.leftHalf, 3), (.rightHalf, 3), (.topHalf, 3), (.bottomHalf, 3),
        (.upperLeft, 3), (.upperRight, 3), (.lowerLeft, 3), (.lowerRight, 3),
        (.nextThird, 6), (.previousThird, 6),
    ]
    for gap in stride(from: CGFloat(0), through: 100, by: 2) {
        for skipTop in [false, true] {
            for (action, period) in cycles {
                let r = presses(action, from: CGRect(x: -1270, y: 910, width: 10, height: 10),
                                period + 1, screen: screen, gap: gap, skipTop: skipTop)
                #expect(Set(r.prefix(period).map { "\($0)" }).count == period && r[period] == r[0],
                        "\(action) gap \(gap) skipTop \(skipTop): \(r)")
            }
        }
    }
}
