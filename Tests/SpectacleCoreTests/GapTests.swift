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
    #expect(right?.minX == 725)          // 715 (working right-half x) + 10 (working inset) ... see note
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
    // gap 10, skipTop → working frame (5,5,1430,895); ½ = 715, ⅔ = 953, ⅓ = 476 wide, each then
    // inset 5 on left/right/bottom only, so the window keeps maxY = 900.
    #expect(presses(.leftHalf, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 10, width: 705, height: 890),
        CGRect(x: 10, y: 10, width: 943, height: 890),
        CGRect(x: 10, y: 10, width: 466, height: 890),
        CGRect(x: 10, y: 10, width: 705, height: 890),
    ])
}

@Test func gapSkipTopTopHalfCycles() {
    // Height cycle: ½ = 447 (bottom at 5 + 447 + 1 = 453), ⅔ = 596, ⅓ = 298, all top-aligned at 900.
    #expect(presses(.topHalf, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 458, width: 1420, height: 442),
        CGRect(x: 10, y: 309, width: 1420, height: 591),
        CGRect(x: 10, y: 607, width: 1420, height: 293),
        CGRect(x: 10, y: 458, width: 1420, height: 442),
    ])
}

@Test func gapSkipTopCornersCycle() {
    #expect(presses(.upperLeft, from: offAxis, 4, gap: 10, skipTop: true) == [
        CGRect(x: 10, y: 458, width: 705, height: 442),
        CGRect(x: 10, y: 458, width: 943, height: 442),
        CGRect(x: 10, y: 458, width: 466, height: 442),
        CGRect(x: 10, y: 458, width: 705, height: 442),
    ])
    // Right-aligned to the working frame's maxX 1435: ⅔ at 1435 - 953, ⅓ at 1435 - 476.
    #expect(presses(.lowerRight, from: CGRect(x: 0, y: 890, width: 10, height: 10), 4,
                    gap: 10, skipTop: true) == [
        CGRect(x: 725, y: 10, width: 705, height: 442),
        CGRect(x: 487, y: 10, width: 943, height: 442),
        CGRect(x: 964, y: 10, width: 466, height: 442),
        CGRect(x: 725, y: 10, width: 705, height: 442),
    ])
}

@Test func gapSkipTopThirdsCycle() {
    // Columns 476 wide at x = 5, 481, 957; rows 298 high at y = 602, 304, 6; each inset 5 (not top).
    let cols = [CGRect(x: 10, y: 10, width: 466, height: 890),
                CGRect(x: 486, y: 10, width: 466, height: 890),
                CGRect(x: 962, y: 10, width: 466, height: 890)]
    let rows = [CGRect(x: 10, y: 607, width: 1420, height: 293),
                CGRect(x: 10, y: 309, width: 1420, height: 293),
                CGRect(x: 10, y: 11, width: 1420, height: 293)]
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
        CGRect(x: 1450, y: 10, width: 943, height: 865),
        CGRect(x: 1450, y: 10, width: 466, height: 865),
        CGRect(x: 1450, y: 10, width: 705, height: 865),
    ])
    // Next Third from the first column moves to the second (x = 1445 + 476 + 5).
    #expect(presses(.nextThird, from: CGRect(x: 1450, y: 10, width: 466, height: 865), 1,
                    screen: screen, gap: 10, skipTop: true)
            == [CGRect(x: 1926, y: 10, width: 466, height: 865)])
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
