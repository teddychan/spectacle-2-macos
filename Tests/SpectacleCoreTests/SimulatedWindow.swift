import CoreGraphics

/// A window as its app sizes it. Spectacle asks for a frame; the app keeps the requested top-left
/// corner (AX anchors windows there) and picks the size itself. Cocoa (bottom-left origin) frames.
final class SimulatedWindow {
    private(set) var frame: CGRect
    /// Every frame Spectacle wrote, in order.
    private(set) var writes: [CGRect] = []
    private let size: (CGSize) -> CGSize

    init(_ frame: CGRect, size: @escaping (CGSize) -> CGSize = { $0 }) {
        self.frame = frame
        self.size = size
    }

    func setFrame(_ r: CGRect) {
        writes.append(r)
        let s = size(r.size)
        frame = CGRect(x: r.minX, y: r.maxY - s.height, width: s.width, height: s.height)
    }

    func resize(_ r: CGRect) -> CGRect? {
        setFrame(r)
        return frame
    }

    /// An app that won't go below a minimum size.
    static func minimum(_ m: CGSize) -> (CGSize) -> CGSize {
        { CGSize(width: max($0.width, m.width), height: max($0.height, m.height)) }
    }

    /// A terminal: rounds each side up to whole character cells.
    static func cells(_ c: CGSize) -> (CGSize) -> CGSize {
        { CGSize(width: ($0.width / c.width).rounded(.up) * c.width,
                 height: ($0.height / c.height).rounded(.up) * c.height) }
    }
}
