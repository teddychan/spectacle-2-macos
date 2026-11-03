import Testing
import CoreGraphics
@testable import SpectacleCore

// Left, Center and Right Third and the three Two Thirds actions: always columns of the destination
// visible frame, the same tile on every press.

private let fixedThirds: [WindowAction] = [
    .leftThird, .centerThird, .rightThird, .leftTwoThirds, .centerTwoThirds, .rightTwoThirds,
]

private let screens: [CGRect] = [
    CGRect(x: 0, y: 0, width: 1440, height: 900),
    CGRect(x: 0, y: 55, width: 1513, height: 757),       // 1 pt left over after dividing by 3
    CGRect(x: -1280, y: 900, width: 1279, height: 777),  // 1 pt over, off the main display
    CGRect(x: 1440, y: 0, width: 1080, height: 1920),    // portrait
]

private let gaps: [WindowGap] = [0, 4, 10, 30].flatMap { size in
    [false, true].map { WindowGap(size: size, skipTopEdge: $0) }
}

private func press(_ action: WindowAction, _ screen: CGRect, _ gap: WindowGap = .none,
                   from win: CGRect? = nil) -> CGRect? {
    let win = win ?? CGRect(x: screen.minX + 100, y: screen.minY + 100, width: 300, height: 200)
    return WindowCalculator.calculate(action, CalculationInput(
        windowRect: win, sourceVisibleFrame: screen, destinationVisibleFrame: screen,
        gap: gap.size, skipGapTopEdge: gap.skipTopEdge))
}

@Test func fixedThirdsAreColumnsOfTheScreen() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(press(.leftThird, screen) == CGRect(x: 0, y: 0, width: 480, height: 900))
    #expect(press(.centerThird, screen) == CGRect(x: 480, y: 0, width: 480, height: 900))
    #expect(press(.rightThird, screen) == CGRect(x: 960, y: 0, width: 480, height: 900))
    #expect(press(.leftTwoThirds, screen) == CGRect(x: 0, y: 0, width: 960, height: 900))
    #expect(press(.centerTwoThirds, screen) == CGRect(x: 240, y: 0, width: 960, height: 900))
    #expect(press(.rightTwoThirds, screen) == CGRect(x: 480, y: 0, width: 960, height: 900))
}

@Test func fixedThirdsGiveTheLeftoverPointToTheRightColumn() {
    let screen = CGRect(x: 0, y: 55, width: 1513, height: 757)
    #expect(press(.leftThird, screen) == CGRect(x: 0, y: 55, width: 504, height: 757))
    #expect(press(.centerThird, screen) == CGRect(x: 504, y: 55, width: 504, height: 757))
    #expect(press(.rightThird, screen) == CGRect(x: 1008, y: 55, width: 505, height: 757))
    #expect(press(.leftTwoThirds, screen) == CGRect(x: 0, y: 55, width: 1008, height: 757))
    #expect(press(.centerTwoThirds, screen) == CGRect(x: 252, y: 55, width: 1008, height: 757))
    #expect(press(.rightTwoThirds, screen) == CGRect(x: 504, y: 55, width: 1009, height: 757))
}

@Test func centerTwoThirdsOnAMacBookAirScreen() {
    let screen = CGRect(x: 0, y: 55, width: 1512, height: 757)
    #expect(press(.centerTwoThirds, screen) == CGRect(x: 252, y: 55, width: 1008, height: 757))
}

@Test func fixedThirdsStayColumnsOnAPortraitScreen() {
    let screen = CGRect(x: 1440, y: 0, width: 1080, height: 1920)
    #expect(press(.leftThird, screen) == CGRect(x: 1440, y: 0, width: 360, height: 1920))
    #expect(press(.centerThird, screen) == CGRect(x: 1800, y: 0, width: 360, height: 1920))
    #expect(press(.rightThird, screen) == CGRect(x: 2160, y: 0, width: 360, height: 1920))
    #expect(press(.leftTwoThirds, screen) == CGRect(x: 1440, y: 0, width: 720, height: 1920))
    #expect(press(.centerTwoThirds, screen) == CGRect(x: 1620, y: 0, width: 720, height: 1920))
    #expect(press(.rightTwoThirds, screen) == CGRect(x: 1800, y: 0, width: 720, height: 1920))
}

@Test func fixedThirdsKeepTheGap() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let gap = WindowGap(size: 10)
    #expect(press(.leftThird, screen, gap) == CGRect(x: 10, y: 10, width: 466, height: 880))
    #expect(press(.centerThird, screen, gap) == CGRect(x: 486, y: 10, width: 466, height: 880))
    #expect(press(.rightThird, screen, gap) == CGRect(x: 962, y: 10, width: 468, height: 880))
    #expect(press(.centerTwoThirds, screen, gap) == CGRect(x: 249, y: 10, width: 942, height: 880))
    // Skipping the top gap lets every column reach the top of the screen.
    let skipTop = WindowGap(size: 10, skipTopEdge: true)
    for action in fixedThirds {
        #expect(press(action, screen, skipTop)?.maxY == screen.maxY, "\(action)")
        #expect(press(action, screen, skipTop)?.minY == 10, "\(action)")
    }
}

@Test func fixedThirdsEqualTheDragSnapTiles() {
    let pairs: [(WindowAction, SnapTarget)] = [
        (.leftThird, .firstThird), (.centerThird, .centerThird), (.rightThird, .lastThird),
        (.leftTwoThirds, .firstTwoThirds), (.rightTwoThirds, .lastTwoThirds),
    ]
    for screen in screens {
        for gap in gaps {
            for (action, target) in pairs {
                #expect(press(action, screen, gap) == SnapGeometry.rect(target, visibleFrame: screen, gap: gap),
                        "\(action) \(screen) \(gap)")
            }
        }
    }
}

@Test func centerTwoThirdsIsAsWideAsLeftTwoThirdsAndCentered() {
    for screen in screens {
        for gap in gaps {
            let center = press(.centerTwoThirds, screen, gap)!
            let left = press(.leftTwoThirds, screen, gap)!
            #expect(center.width == left.width, "\(screen) \(gap)")
            #expect(center.minY == left.minY && center.height == left.height, "\(screen) \(gap)")
            let leftMargin = center.minX - screen.minX, rightMargin = screen.maxX - center.maxX
            #expect(rightMargin - leftMargin >= 0 && rightMargin - leftMargin <= 1, "\(screen) \(gap)")
        }
    }
}

@Test func pressingAFixedThirdAgainKeepsTheSameTile() {
    for screen in screens {
        for gap in gaps {
            for action in fixedThirds {
                let first = press(action, screen, gap)
                #expect(press(action, screen, gap, from: first) == first, "\(action) \(screen) \(gap)")
            }
        }
    }
}

@Test func fixedThirdsRecordUndoHistory() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let start = CGRect(x: 300, y: 200, width: 500, height: 400)
    for action in fixedThirds {
        var history = WindowHistory()
        let outcome = WindowActionResolver.resolve(
            action: action, windowID: 1, currentFrame: start,
            sourceVisibleFrame: screen, destinationVisibleFrame: screen, history: &history)
        guard case .move(let moved) = outcome else {
            Issue.record("\(action) did not move")
            continue
        }
        #expect(history.undo(current: moved, for: 1) == start, "\(action)")
        #expect(WindowActionResolver.displayDirection(for: action) == 0, "\(action)")
    }
}
