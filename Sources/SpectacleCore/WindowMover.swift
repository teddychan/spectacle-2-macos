import CoreGraphics

/// The one path every window move takes, keyboard action or drag-to-snap. Port of Spectacle's
/// chained movers, in the original's order: the standard mover writes the frame, then the
/// best-effort mover reads it back and shifts the window inside the visible frame if the app
/// refused the size. The caller supplies the AX write and read; all rects are Cocoa.
public enum WindowMover {
    public static func move(to requested: CGRect, visibleFrame: CGRect,
                            setFrame: (CGRect) -> Void, frame: () -> CGRect?) {
        setFrame(requested)
        // Read straight back, as the original did, with no delay.
        guard let actual = frame(),
              let fixed = BestEffortMove.correctedFrame(
                  requested: requested, actual: actual, visibleFrame: visibleFrame) else { return }
        setFrame(fixed)
    }
}
