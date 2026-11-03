import Foundation

/// Neutral modifier set — no Carbon/AppKit. The app translates to Carbon masks in HotKeyManager.
public struct ModifierFlags: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let control = ModifierFlags(rawValue: 1 << 0)
    public static let option  = ModifierFlags(rawValue: 1 << 1)
    public static let shift   = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
}

public struct Shortcut: Codable, Equatable, Sendable, Hashable {
    public var keyCode: UInt16
    public var modifiers: ModifierFlags
    public init(keyCode: UInt16, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// e.g. "⌥⌘←". Modifier order matches macOS: ⌃⌥⇧⌘.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + Self.keyLabel(keyCode)
    }

    /// The key alone, as `displayString` shows it: "←", "C", "Space", or "Key N" for an unlabelled code.
    public var keyLabel: String { Self.keyLabel(keyCode) }

    static func keyLabel(_ code: UInt16) -> String {
        switch code {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36:  return "↩"
        case 48:  return "⇥"
        case 49:  return "Space"
        case 51:  return "⌫"
        case 53:  return "⎋"
        default:  return Self.ansiLabels[code] ?? "Key \(code)"
        }
    }

    /// ANSI virtual key codes → uppercase label (subset covering the defaults; extend as needed).
    private static let ansiLabels: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
    ]
}
