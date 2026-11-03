import CoreGraphics

/// Port of Spectacle's `SpectacleQuantizedWindowMover`: some apps size windows in steps
/// (terminals round up to whole character cells), so a window can come out larger than requested
/// and overlap the next tile. Shrink the request 2 pt at a time, re-reading the window after each
/// write, until it fits or the request falls below 85% of the requested size, then centre the
/// window on the requested rect. All rects are Cocoa (bottom-left origin); AX anchors a window at
/// its top-left, so every write keeps the requested top-left corner, as the original's did.
public enum QuantizedMove {
    static let step: CGFloat = 2
    /// The original's `0.85f`: a Float, so the floor sits a hair above 85% (720 → 612.00002).
    static let floor = CGFloat(Float(0.85))
    /// How much shrink a side may ignore before the loop stops shrinking it (not in the original).
    /// Terminal rows are at most about 20 pt, so a terminal changes size well within it; a window
    /// held at a minimum size never does, and walking it to the floor would cost dozens of
    /// synchronous AX round trips on the main thread for nothing.
    static let patience: CGFloat = 32

    /// Writes through `resize` (set the frame, return the frame the window took, or nil when it
    /// can't be read) and returns where the window ended up, or nil once a read fails.
    ///
    /// The loop is bounded by the floor: each pass shrinks at least one side by `step`, so a
    /// requested w × h makes at most about 0.075 × (w + h) writes, plus the centring write. A
    /// window that ignores the shrink stops after `patience / step` writes.
    public static func fit(requested: CGRect, actual: CGRect, resize: (CGRect) -> CGRect?) -> CGRect? {
        guard actual != requested else { return actual }
        let top = requested.maxY
        var size = requested.size
        var moved = actual
        var ignored = CGSize.zero   // shrink each side has ignored since its size last changed
        while true {
            let shrinkWidth = moved.width > requested.width && ignored.width < patience
            let shrinkHeight = moved.height > requested.height && ignored.height < patience
            guard shrinkWidth || shrinkHeight else { break }
            if shrinkWidth { size.width -= step }
            if shrinkHeight { size.height -= step }
            if size.width < requested.width * floor || size.height < requested.height * floor { break }
            guard let read = resize(CGRect(x: requested.minX, y: top - size.height,
                                           width: size.width, height: size.height)) else { return nil }
            ignored.width = read.width != moved.width ? 0 : ignored.width + (shrinkWidth ? step : 0)
            ignored.height = read.height != moved.height ? 0 : ignored.height + (shrinkHeight ? step : 0)
            moved = read
        }
        // Centre on the requested rect by the size the window last took. Past the floor, `size`
        // is one step under the last write; the original wrote it anyway, and so does this.
        let left = requested.minX + ((requested.width - moved.width) / 2).rounded(.down)
        let centredTop = top - ((requested.height - moved.height) / 2).rounded(.down)
        return resize(CGRect(x: left, y: centredTop - size.height, width: size.width, height: size.height))
    }
}
