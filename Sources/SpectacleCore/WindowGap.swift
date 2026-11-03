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

    /// The gapped window for a rect `r` tiled in working frame `f` (the visible frame inset by
    /// `half` on every edge): `r` inset by `half`. With `skipTop`, a rect against the top of `f`
    /// first grows up to the top of the screen, so only that edge loses its gap and stacked windows
    /// stay a full gap apart (#63).
    public static func tile(_ r: CGRect, in f: CGRect, half: CGFloat, skipTop: Bool) -> CGRect {
        let top = skipTop && reachesTop(r, f, half)
        var out = r
        if top { out.size.height += half }
        return inset(out, half: half, skipTop: top)
    }

    /// The exact inverse of `tile`: the rect a gapped window was tiled from.
    public static func untile(_ r: CGRect, in f: CGRect, half: CGFloat, skipTop: Bool) -> CGRect {
        let top = skipTop && reachesTop(r, f, half)
        var out = outset(r, half: half, skipTop: top)
        if top { out.size.height -= half }
        return out
    }

    /// Whether a tiled rect is against the top of `f`, read alike before `tile` (top at `f.maxY`) and
    /// after it (top at `f.maxY + half`). Any other tile ends at least `half` below `f.maxY` once gapped.
    private static func reachesTop(_ r: CGRect, _ f: CGRect, _ half: CGFloat) -> Bool {
        r.maxY > f.maxY - half
    }
}
