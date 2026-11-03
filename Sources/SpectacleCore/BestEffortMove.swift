import CoreGraphics

/// Port of Spectacle's `SpectacleBestEffortWindowMover`: after a move, an app may refuse the
/// requested size (minimum sizes, fixed-size windows, terminals snapping to character cells),
/// leaving the window hanging off an edge. Given the frame it actually took, shift it back inside
/// the visible frame without resizing it. All rects are Cocoa (bottom-left origin).
public enum BestEffortMove {
    /// The frame to move the window to, or nil when no second move is needed.
    ///
    /// Each axis follows the original: a window past the left (bottom) edge moves right (up), one
    /// past the right (top) edge moves left (down). Two deliberate differences:
    /// - A window larger than the visible frame on an axis pins its left or top edge, so the title
    ///   bar and window buttons stay reachable; the original could push them off screen.
    /// - A window that took `requested` exactly is left alone, so Undo restores a frame the user
    ///   had placed partly off screen; the original clamped that too.
    public static func correctedFrame(requested: CGRect, actual: CGRect, visibleFrame vf: CGRect) -> CGRect? {
        guard actual != requested else { return nil }
        var r = actual
        if r.minX < vf.minX || r.width > vf.width {
            r.origin.x = vf.minX
        } else if r.maxX > vf.maxX {
            r.origin.x = vf.maxX - r.width
        }
        if r.maxY > vf.maxY || r.height > vf.height {
            r.origin.y = vf.maxY - r.height
        } else if r.minY < vf.minY {
            r.origin.y = vf.minY
        }
        return r == actual ? nil : r
    }
}
