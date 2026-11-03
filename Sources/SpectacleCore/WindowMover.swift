import CoreGraphics

/// The one path every window move takes, keyboard action or drag-to-snap. Port of Spectacle's
/// chained movers, in the original's order: the standard mover writes the frame; the quantized
/// mover shrinks a window that came out larger than asked (`QuantizedMove`); the best-effort
/// mover shifts it inside the visible frame if it still doesn't fit (`BestEffortMove`). The
/// caller supplies the AX write and read; all rects are Cocoa.
public enum WindowMover {
    public static func move(to requested: CGRect, visibleFrame: CGRect,
                            setFrame: (CGRect) -> Void, frame: () -> CGRect?) {
        setFrame(requested)
        // Read straight back, as the original did, with no delay.
        guard let actual = frame(),
              let settled = QuantizedMove.fit(requested: requested, actual: actual, resize: {
                  setFrame($0)
                  return frame()
              }),
              let fixed = BestEffortMove.correctedFrame(
                  requested: requested, actual: settled, visibleFrame: visibleFrame) else { return }
        setFrame(fixed)
    }
}
