import Foundation
import CoreGraphics

public struct CalculationInput: Equatable, Sendable {
    public var windowRect: CGRect
    public var sourceVisibleFrame: CGRect
    public var destinationVisibleFrame: CGRect
    /// Total gap (points) applied around and between tiled windows. 0 = no gaps (default).
    public var gap: CGFloat
    /// When true, no gap is applied at the top edge of the screen.
    public var skipGapTopEdge: Bool
    public init(windowRect: CGRect,
                sourceVisibleFrame: CGRect,
                destinationVisibleFrame: CGRect,
                gap: CGFloat = 0,
                skipGapTopEdge: Bool = false) {
        self.windowRect = windowRect
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
        self.gap = gap
        self.skipGapTopEdge = skipGapTopEdge
    }
}

/// Pure window-position math, a 1:1 port of Spectacle's JavaScriptCore calculations.
/// Returns the new window rect, or nil for a no-op (or a non-geometry action).
public enum WindowCalculator {
    public static func calculate(_ action: WindowAction, _ input: CalculationInput) -> CGRect? {
        let win = input.windowRect
        let vf = input.destinationVisibleFrame
        let half = input.gap / 2
        let skip = input.skipGapTopEdge
        // Working frame: the visible frame shrunk by half the gap on every edge. Skipping the top
        // gap does not change the layout, only how far the top tiles reach (#63).
        let frame = WindowGap.inset(vf, half: half, skipTop: false)
        // Gap-applicable results are shrunk by the other half; size-preserving actions are not.
        func g(_ r: CGRect) -> CGRect { WindowGap.tile(r, in: frame, half: half, skipTop: skip) }
        // The cycling checks compare the window with un-gapped candidates, so undo `g` first. With
        // skipTop a top tile is lopsided and its center sits off the candidate's (#57).
        let tiled = WindowGap.untile(win, in: frame, half: half, skipTop: skip)
        switch action {
        case .leftHalf:   return g(leftHalf(tiled, frame))
        case .rightHalf:  return g(rightHalf(tiled, frame))
        case .topHalf:    return g(topHalf(tiled, frame))
        case .bottomHalf: return g(bottomHalf(tiled, frame))
        case .upperLeft:  return g(upperLeft(tiled, frame))
        case .upperRight: return g(upperRight(tiled, frame))
        case .lowerLeft:  return g(lowerLeft(tiled, frame))
        case .lowerRight: return g(lowerRight(tiled, frame))
        case .center:     return center(win, vf)            // size-preserving → ungapped
        case .fullscreen: return g(frame)                   // == vf inset by full gap
        case .makeLarger:  return WindowSizeAdjuster.resize(win, vf, offset: 30)
        case .makeSmaller: return WindowSizeAdjuster.resize(win, vf, offset: -30)
        case .nextThird:     return g(third(tiled, frame, step: +1))
        case .previousThird: return g(third(tiled, frame, step: -1))
        case .leftThird:       return g(thirds(frame)[0])
        case .centerThird:     return g(thirds(frame)[1])
        case .rightThird:      return g(thirds(frame)[2])
        case .leftTwoThirds:   return g(leftTwoThirds(frame))
        case .centerTwoThirds: return g(centerTwoThirds(frame))
        case .rightTwoThirds:  return g(rightTwoThirds(frame))
        case .nextDisplay, .previousDisplay:
            return SpectacleGeometry.rectFitsWithin(win: win, screen: vf) ? center(win, vf) : g(frame)
        case .undo, .redo: return nil
        }
    }

    // MARK: Halves

    // A nil `win` has nothing to cycle from, so halves and corners return the plain tile (drag-snap).
    // The ⅔ and ⅓ steps are made of the thirds columns and rows, so they line up with them (#70).
    static func leftHalf(_ win: CGRect?, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)          // left-aligned at f.x
        guard let win, abs(win.midY - base.midY) <= 1.0 else { return base }
        let cols = thirds(f)
        let twoThird = cols[0].union(cols[1])
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) { return cols[0] }
        return base
    }

    static func rightHalf(_ win: CGRect?, _ f: CGRect) -> CGRect {
        var base = f
        base.origin.x += floor(f.width / 2.0)
        base.size.width = f.maxX - base.minX              // the odd point goes to the right half (#70)
        guard let win, abs(win.midY - base.midY) <= 1.0 else { return base }
        let cols = thirds(f)
        let twoThird = cols[1].union(cols[2])
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) { return cols[2] }
        return base
    }

    static func topHalf(_ win: CGRect?, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)
        base.origin.y = topY(f)
        guard let win, abs(win.midX - base.midX) <= 1.0 else { return base }
        let rows = Array(thirds(f)[3...])                 // top, middle, bottom
        let twoThirds = rows[0].union(rows[1])
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) { return rows[0] }
        return base
    }

    static func bottomHalf(_ win: CGRect?, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = topY(f) - f.minY               // bottom-aligned at f.y, up to the top half
        guard let win, abs(win.midX - base.midX) <= 1.0 else { return base }
        let rows = Array(thirds(f)[3...])                 // top, middle, bottom
        let twoThirds = rows[1].union(rows[2])
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) { return rows[2] }
        return base
    }

    // MARK: Corners

    /// Where the top half starts. The bottom half runs up to it, so an odd point goes to the bottom
    /// half, as the remainder goes to the bottom thirds row (#70).
    private static func topY(_ f: CGRect) -> CGFloat {
        f.origin.y + floor(f.height / 2.0) + f.height.truncatingRemainder(dividingBy: 2.0)
    }

    // Each quarter is where two halves overlap, so it shares their edges and odd points.
    static func upperLeft(_ win: CGRect?, _ f: CGRect) -> CGRect {
        cornerCycle(win, f, quarter: leftHalf(nil, f).intersection(topHalf(nil, f)), rightAligned: false)
    }
    static func upperRight(_ win: CGRect?, _ f: CGRect) -> CGRect {
        cornerCycle(win, f, quarter: rightHalf(nil, f).intersection(topHalf(nil, f)), rightAligned: true)
    }
    static func lowerLeft(_ win: CGRect?, _ f: CGRect) -> CGRect {
        cornerCycle(win, f, quarter: leftHalf(nil, f).intersection(bottomHalf(nil, f)), rightAligned: false)
    }
    static func lowerRight(_ win: CGRect?, _ f: CGRect) -> CGRect {
        cornerCycle(win, f, quarter: rightHalf(nil, f).intersection(bottomHalf(nil, f)), rightAligned: true)
    }

    /// Shared quarter → ⅔-width → ⅓-width cycle (height and vertical edge fixed).
    private static func cornerCycle(_ win: CGRect?, _ f: CGRect, quarter q: CGRect, rightAligned: Bool) -> CGRect {
        guard let win, abs(win.midY - q.midY) <= 1.0 else { return q }
        let cols = thirds(f)
        func across(_ c: CGRect) -> CGRect {
            var r = q; r.origin.x = c.minX; r.size.width = c.width
            return r
        }
        let twoThird = across(rightAligned ? cols[1].union(cols[2]) : cols[0].union(cols[1]))
        if SpectacleGeometry.rectCenteredWithin(container: q, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            return across(rightAligned ? cols[2] : cols[0])
        }
        return q
    }

    // MARK: Center

    /// An axis the window is too big for pins it to the frame's left or bottom edge instead of going
    /// negative, as the original's best-effort mover did after every move (#61).
    static func center(_ win: CGRect, _ f: CGRect) -> CGRect {
        var r = win
        r.origin.x = max(0, ((f.width - win.width) / 2.0).rounded()) + f.origin.x
        r.origin.y = max(0, ((f.height - win.height) / 2.0).rounded()) + f.origin.y
        return r
    }

    // MARK: Thirds — 3 vertical columns then 3 horizontal rows

    /// Each third is floored as in the original, but the right column and the bottom row run to the
    /// frame's edge, so the remainder (0–2 pt) goes to them rather than to the margin (#64).
    static func thirds(_ f: CGRect) -> [CGRect] {
        var regions: [CGRect] = []
        let w = floor(f.width / 3.0)
        for i in 0..<3 {
            var r = f; r.origin.x = f.origin.x + w * CGFloat(i); r.size.width = w
            if i == 2 { r.size.width = f.maxX - r.minX }
            regions.append(r)
        }
        let h = floor(f.height / 3.0)
        for i in 0..<3 {
            var r = f
            r.origin.y = f.origin.y + f.height - h * CGFloat(i + 1)
            r.size.height = h
            if i == 2 { r.size.height = r.maxY - f.minY; r.origin.y = f.minY }
            regions.append(r)
        }
        return regions
    }

    static func third(_ win: CGRect, _ f: CGRect, step: Int) -> CGRect {
        let regions = thirds(f)
        for (i, region) in regions.enumerated() where SpectacleGeometry.rectCenteredWithin(container: region, win: win) {
            let j = ((i + step) % regions.count + regions.count) % regions.count
            return regions[j]
        }
        return regions[0]
    }

    // MARK: Fixed thirds — always columns, the same tile on every press

    static func leftTwoThirds(_ f: CGRect) -> CGRect {
        let cols = thirds(f)
        return cols[0].union(cols[1])
    }

    static func rightTwoThirds(_ f: CGRect) -> CGRect {
        let cols = thirds(f)
        return cols[1].union(cols[2])
    }

    /// Two whole columns wide, as Left Two Thirds is (Right Two Thirds also takes the leftover
    /// points), and centered in the frame.
    static func centerTwoThirds(_ f: CGRect) -> CGRect {
        var r = leftTwoThirds(f)
        r.origin.x = f.minX + floor((f.width - r.width) / 2.0)
        return r
    }
}
