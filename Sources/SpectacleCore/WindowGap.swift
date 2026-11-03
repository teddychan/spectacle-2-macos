import CoreGraphics

/// A window-gap setting: a total spacing (points) plus whether to skip the top edge.
/// The gap is realized as a "half-gap applied twice" — once to the working frame and once to
/// each produced rect — so outer screen edges and the space between two tiled windows both end
/// up exactly `size` points. See `WindowCalculator.calculate`.
public struct WindowGap: Equatable, Sendable {
    public var size: CGFloat
    public var skipTopEdge: Bool
    public init(size: CGFloat = 0, skipTopEdge: Bool = false) {
        self.size = size
        self.skipTopEdge = skipTopEdge
    }
    public static let none = WindowGap()

    /// Shrink `r` by `half` points on each edge. In Cocoa (bottom-left origin) the top edge is
    /// `maxY`; `skipTop` leaves it untouched. `half <= 0` returns `r` unchanged.
    public static func inset(_ r: CGRect, half: CGFloat, skipTop: Bool) -> CGRect {
        guard half > 0 else { return r }
        var out = r
        out.origin.x += half
        out.size.width -= 2 * half
        out.origin.y += half                              // bottom edge
        out.size.height -= skipTop ? half : 2 * half      // top edge optional
        return out
    }

    /// The exact inverse of `inset`: grow `r` back by `half` on each edge (top optional). Turns a
    /// gapped window back into the un-gapped rect it was tiled from.
    public static func outset(_ r: CGRect, half: CGFloat, skipTop: Bool) -> CGRect {
        guard half > 0 else { return r }
        var out = r
        out.origin.x -= half
        out.size.width += 2 * half
        out.origin.y -= half
        out.size.height += skipTop ? half : 2 * half
        return out
    }
}
