public enum WindowAction: String, CaseIterable, Codable, Sendable {
    case center, fullscreen
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case nextThird, previousThird
    case leftThird, centerThird, rightThird
    case leftTwoThirds, centerTwoThirds, rightTwoThirds
    case nextDisplay, previousDisplay
    case makeLarger, makeSmaller
    case undo, redo

    /// Actions computed by `WindowCalculator` (everything except undo/redo).
    public static var geometryActions: [WindowAction] {
        allCases.filter { $0 != .undo && $0 != .redo }
    }
}
