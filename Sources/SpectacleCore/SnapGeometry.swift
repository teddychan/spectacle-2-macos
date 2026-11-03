import CoreGraphics

/// A drag-snap landing target. Unlike `WindowCalculator` these never cycle (½→⅔→⅓) — a fresh
/// drag-snap always produces the plain tile — but they honor the configured `WindowGap`.
public enum SnapTarget: Equatable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight   // quarters
    case maximize
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
}

public enum SnapGeometry {
    /// The Cocoa (bottom-left origin) rect for `target` within `visibleFrame`, with `gap` applied.
    /// Built like `WindowCalculator`'s plain tiles, so a snapped half equals a keyboard half (#67).
    /// Two-thirds span two of the keyboard's columns, so every inner gap stays `gap.size` (#68), and
    /// equal the ⅔ step of Left Half and Right Half (#70).
    public static func rect(_ target: SnapTarget, visibleFrame vf: CGRect, gap: WindowGap) -> CGRect {
        let half = gap.size / 2
        let f = WindowGap.inset(vf, half: half, skipTop: false)   // working frame, as the keyboard's
        let cols = WindowCalculator.thirds(f)                       // [0..<3] are the columns
        let plain: CGRect
        switch target {
        case .leftHalf:    plain = WindowCalculator.leftHalf(nil, f)
        case .rightHalf:   plain = WindowCalculator.rightHalf(nil, f)
        case .topHalf:     plain = WindowCalculator.topHalf(nil, f)
        case .bottomHalf:  plain = WindowCalculator.bottomHalf(nil, f)
        case .topLeft:     plain = WindowCalculator.upperLeft(nil, f)
        case .topRight:    plain = WindowCalculator.upperRight(nil, f)
        case .bottomLeft:  plain = WindowCalculator.lowerLeft(nil, f)
        case .bottomRight: plain = WindowCalculator.lowerRight(nil, f)
        case .maximize:    plain = f
        case .firstThird:  plain = cols[0]
        case .centerThird: plain = cols[1]
        case .lastThird:   plain = cols[2]
        case .firstTwoThirds: plain = cols[0].union(cols[1])
        case .lastTwoThirds:  plain = cols[1].union(cols[2])
        }
        return WindowGap.tile(plain, in: f, half: half, skipTop: gap.skipTopEdge)
    }

    public enum SnapZone: Equatable, Sendable {
        case top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }
    public enum ThirdColumn: Equatable, Sendable { case first, center, last }

    /// Rectangle default zone geometry (points).
    public static let edgeMargin: CGFloat = 5
    public static let cornerSize: CGFloat = 20        // → 25pt corner band with the 5pt margin
    public static let shortEdgeSize: CGFloat = 145

    /// The zone the cursor is in for a screen (Cocoa coords), or nil if in the interior.
    /// Corners take priority over edges.
    public static func zone(for c: CGPoint, in s: CGRect) -> SnapZone? {
        guard s.contains(c) else { return nil }
        let band = edgeMargin + cornerSize                    // 25
        let nearLeft = c.x < s.minX + band
        let nearRight = c.x > s.maxX - band
        let nearTop = c.y > s.maxY - band                     // Cocoa: top = maxY
        let nearBottom = c.y < s.minY + band
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if c.x < s.minX + edgeMargin { return .left }
        if c.x > s.maxX - edgeMargin { return .right }
        if c.y > s.maxY - edgeMargin { return .top }
        if c.y < s.minY + edgeMargin { return .bottom }
        return nil
    }

    /// On a left/right edge: within `shortEdgeSize` of the top → top half, of the bottom → bottom
    /// half, else nil (→ plain side half). Cocoa coords.
    public static func sideEdgeHalf(cursorY y: CGFloat, in s: CGRect) -> SnapTarget? {
        if y >= s.maxY - shortEdgeSize { return .topHalf }
        if y <= s.minY + shortEdgeSize { return .bottomHalf }
        return nil
    }

    /// Which horizontal third the cursor's x falls in.
    public static func bottomEdgeThird(cursorX x: CGFloat, in s: CGRect) -> ThirdColumn {
        let third = s.width / 3
        if x <= s.minX + third { return .first }
        if x >= s.maxX - third { return .last }
        return .center
    }

    /// Maps a `SnapZone` (plus cursor/screen context) to the `SnapTarget` it should land on.
    /// `previousBottomColumn` carries the last `.bottom`-zone column across calls so two-thirds
    /// promotion (entering the center third from a side third) can be detected; the returned
    /// `bottomColumn` is only ever refreshed for a `.bottom` zone — for every other zone it is
    /// `previousBottomColumn` unchanged, so callers can unconditionally store the result back.
    public static func target(
        for zone: SnapZone,
        cursor: CGPoint,
        screen: CGRect,
        previousBottomColumn: ThirdColumn?
    ) -> (target: SnapTarget, bottomColumn: ThirdColumn?) {
        switch zone {
        case .top: return (.maximize, previousBottomColumn)
        case .topLeft: return (.topLeft, previousBottomColumn)
        case .topRight: return (.topRight, previousBottomColumn)
        case .bottomLeft: return (.bottomLeft, previousBottomColumn)
        case .bottomRight: return (.bottomRight, previousBottomColumn)
        case .left:
            return (sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .leftHalf, previousBottomColumn)
        case .right:
            return (sideEdgeHalf(cursorY: cursor.y, in: screen) ?? .rightHalf, previousBottomColumn)
        case .bottom:
            let col = bottomEdgeThird(cursorX: cursor.x, in: screen)
            // Two-thirds promotion: entering the center third from a side third widens to two-thirds.
            if col == .center, let prev = previousBottomColumn {
                if prev == .first { return (.firstTwoThirds, col) }
                if prev == .last { return (.lastTwoThirds, col) }
            }
            switch col {
            case .first: return (.firstThird, col)
            case .center: return (.centerThird, col)
            case .last: return (.lastThird, col)
            }
        }
    }
}
