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
        // Working frame: the visible frame shrunk by half the gap (top optional).
        let frame = WindowGap.inset(vf, half: half, skipTop: skip)
        // Gap-applicable results are shrunk by the other half; size-preserving actions are not.
        func g(_ r: CGRect) -> CGRect { WindowGap.inset(r, half: half, skipTop: skip) }
        // The cycling checks compare the window with un-gapped candidates, so undo `g` first. With
        // skipTop the inset is lopsided and moves the center off the candidate's by gap/4 (#57).
        let tiled = WindowGap.outset(win, half: half, skipTop: skip)
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
        case .nextDisplay, .previousDisplay:
            return SpectacleGeometry.rectFitsWithin(win: win, screen: vf) ? center(win, vf) : g(frame)
        case .undo, .redo: return nil
        }
    }

    // MARK: Halves

    static func leftHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)          // left-aligned at f.x
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base; twoThird.size.width = floor(f.width * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base; oneThird.size.width = floor(f.width / 3.0); return oneThird
        }
        return base
    }

    static func rightHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.width = floor(f.width / 2.0)
        base.origin.x += base.width
        guard abs(win.midY - base.midY) <= 1.0 else { return base }
        var twoThird = base
        twoThird.size.width = floor(f.width * 2.0 / 3.0)
        twoThird.origin.x = f.maxX - twoThird.width
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            var oneThird = base
            oneThird.size.width = floor(f.width / 3.0)
            oneThird.origin.x = f.maxX - oneThird.width
            return oneThird
        }
        return base
    }

    static func topHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)
        base.origin.y = topY(f)
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base
        twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        twoThirds.origin.y = f.maxY - twoThirds.height
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base
            oneThird.size.height = floor(f.height / 3.0)
            oneThird.origin.y = f.maxY - oneThird.height
            return oneThird
        }
        return base
    }

    static func bottomHalf(_ win: CGRect, _ f: CGRect) -> CGRect {
        var base = f
        base.size.height = floor(f.height / 2.0)          // bottom-aligned at f.y
        guard abs(win.midX - base.midX) <= 1.0 else { return base }
        var twoThirds = base; twoThirds.size.height = floor(f.height * 2.0 / 3.0)
        if SpectacleGeometry.rectCenteredWithin(container: base, win: win) { return twoThirds }
        if SpectacleGeometry.rectCenteredWithin(container: twoThirds, win: win) {
            var oneThird = base; oneThird.size.height = floor(f.height / 3.0); return oneThird
        }
        return base
    }

    // MARK: Corners

    private static func topY(_ f: CGRect) -> CGFloat {
        f.origin.y + floor(f.height / 2.0) + f.height.truncatingRemainder(dividingBy: 2.0)
    }

    static func upperLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func upperRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width; q.origin.y = topY(f)
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }
    static func lowerLeft(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        return cornerCycle(win, f, quarter: q, rightAligned: false)
    }
    static func lowerRight(_ win: CGRect, _ f: CGRect) -> CGRect {
        var q = f
        q.size.width = floor(f.width / 2.0); q.size.height = floor(f.height / 2.0)
        q.origin.x += q.width
        return cornerCycle(win, f, quarter: q, rightAligned: true)
    }

    /// Shared quarter → ⅔-width → ⅓-width cycle (height and vertical edge fixed).
    private static func cornerCycle(_ win: CGRect, _ f: CGRect, quarter q: CGRect, rightAligned: Bool) -> CGRect {
        guard abs(win.midY - q.midY) <= 1.0 else { return q }
        func widthVariant(_ w: CGFloat) -> CGRect {
            var r = q; r.size.width = w
            if rightAligned { r.origin.x = f.maxX - w }
            return r
        }
        let twoThird = widthVariant(floor(f.width * 2.0 / 3.0))
        if SpectacleGeometry.rectCenteredWithin(container: q, win: win) { return twoThird }
        if SpectacleGeometry.rectCenteredWithin(container: twoThird, win: win) {
            return widthVariant(floor(f.width / 3.0))
        }
        return q
    }

    // MARK: Center

    static func center(_ win: CGRect, _ f: CGRect) -> CGRect {
        var r = win
        r.origin.x = ((f.width - win.width) / 2.0).rounded() + f.origin.x
        r.origin.y = ((f.height - win.height) / 2.0).rounded() + f.origin.y
        return r
    }

    // MARK: Thirds — 3 vertical columns then 3 horizontal rows

    static func thirds(_ f: CGRect) -> [CGRect] {
        var regions: [CGRect] = []
        let w = floor(f.width / 3.0)
        for i in 0..<3 {
            var r = f; r.origin.x = f.origin.x + w * CGFloat(i); r.size.width = w; regions.append(r)
        }
        let h = floor(f.height / 3.0)
        for i in 0..<3 {
            var r = f
            r.origin.y = f.origin.y + f.height - h * CGFloat(i + 1)
            r.size.height = h
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
}
