import Foundation
import CoreGraphics

enum WindowSizeAdjuster {
    static func resize(_ windowRect: CGRect, _ frame: CGRect, offset: CGFloat) -> CGRect {
        var r = windowRect
        r.size.width += offset
        r.origin.x -= floor(offset / 2.0)
        r = adjustLeftRight(original: windowRect, resized: r, frame: frame)
        if r.width >= frame.width { r.size.width = frame.width }
        r.size.height += offset
        r.origin.y -= floor(offset / 2.0)
        r = adjustTopBottom(original: windowRect, resized: r, frame: frame)
        if r.height >= frame.height { r.size.height = frame.height; r.origin.y = windowRect.origin.y }
        if againstAllEdges(windowRect, frame), offset < 0 {
            r.size.width = windowRect.width + offset
            r.origin.x = windowRect.origin.x - floor(offset / 2.0)
            r.size.height = windowRect.height + offset
            r.origin.y = windowRect.origin.y - floor(offset / 2.0)
        }
        if isTooSmall(r, frame) { return windowRect }
        return clamped(r, frame)
    }

    /// Shifts `w` back inside `f` without resizing it, as the original's best-effort mover did after
    /// every move: an edge more than 5 pt away isn't snapped, so the ±15 shift can overshoot it.
    private static func clamped(_ w: CGRect, _ f: CGRect) -> CGRect {
        var c = w
        c.origin.x = max(f.minX, min(c.origin.x, f.maxX - c.width))
        c.origin.y = max(f.minY, min(c.origin.y, f.maxY - c.height))
        return c
    }

    private static func againstEdge(_ gap: CGFloat) -> Bool { abs(gap) <= 5.0 }
    private static func againstLeft(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.minX - f.minX) }
    private static func againstRight(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.maxX - f.maxX) }
    private static func againstTop(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.maxY - f.maxY) }
    private static func againstBottom(_ w: CGRect, _ f: CGRect) -> Bool { againstEdge(w.minY - f.minY) }
    private static func againstAllEdges(_ w: CGRect, _ f: CGRect) -> Bool {
        againstLeft(w, f) && againstRight(w, f) && againstTop(w, f) && againstBottom(w, f)
    }

    private static func adjustLeftRight(original: CGRect, resized: CGRect, frame: CGRect) -> CGRect {
        var a = resized
        if againstRight(original, frame) {
            a.origin.x = frame.maxX - a.width
            if againstLeft(original, frame) { a.size.width = frame.width }
        }
        if againstLeft(original, frame) { a.origin.x = frame.minX }
        return a
    }
    private static func adjustTopBottom(original: CGRect, resized: CGRect, frame: CGRect) -> CGRect {
        var a = resized
        if againstTop(original, frame) {
            a.origin.y = frame.maxY - a.height
            if againstBottom(original, frame) { a.size.height = frame.height }
        }
        if againstBottom(original, frame) { a.origin.y = frame.minY }
        return a
    }
    private static func isTooSmall(_ w: CGRect, _ f: CGRect) -> Bool {
        w.width <= floor(f.width / 4.0) || w.height <= floor(f.height / 4.0)
    }
}
