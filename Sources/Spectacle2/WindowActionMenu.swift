import AppKit
import DragonKit
import SpectacleCore

/// The Window Actions in display order, grouped the way Spectacle's preferences lay them out.
/// The Shortcuts pane's sections list every action; the Status Menu's separated groups list
/// `menuActions`.
struct WindowActionGroup {
    let titleKey: String
    let actions: [WindowAction]

    /// Next and Previous Third step through tiles one press at a time, which suits a Shortcut but
    /// not a menu opened for each step, so they keep only their Shortcuts.
    static let shortcutOnly: Set<WindowAction> = [.nextThird, .previousThird]

    var menuActions: [WindowAction] { actions.filter { !Self.shortcutOnly.contains($0) } }

    static let all: [WindowActionGroup] = [
        WindowActionGroup(titleKey: "app.shortcuts.section.halves",
                          actions: [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        WindowActionGroup(titleKey: "app.shortcuts.section.corners",
                          actions: [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
        WindowActionGroup(titleKey: "app.shortcuts.section.thirds",
                          actions: [.leftThird, .centerThird, .rightThird, .nextThird, .previousThird]),
        WindowActionGroup(titleKey: "app.shortcuts.section.twoThirds",
                          actions: [.leftTwoThirds, .centerTwoThirds, .rightTwoThirds]),
        WindowActionGroup(titleKey: "app.shortcuts.section.sizing",
                          actions: [.center, .fullscreen, .makeLarger, .makeSmaller]),
        WindowActionGroup(titleKey: "app.shortcuts.section.displays",
                          actions: [.nextDisplay, .previousDisplay]),
        WindowActionGroup(titleKey: "app.shortcuts.section.history",
                          actions: [.undo, .redo]),
    ]
}

/// What the Status Menu can offer right now. A Window Action needs Accessibility and a Target
/// Window; the display moves also need a second display to move to.
struct WindowActionAvailability {
    var isTrusted: Bool
    var hasTargetWindow: Bool
    var displayCount: Int

    func isEnabled(_ action: WindowAction) -> Bool {
        guard isTrusted, hasTargetWindow else { return false }
        return displayCount > 1 || WindowActionResolver.displayDirection(for: action) == 0
    }
}

@MainActor
enum WindowActionMenu {
    /// One item per Window Action, groups separated, ending in a separator so the caller can
    /// append its own items. Choosing one has `controller` perform its action.
    static func items(shortcuts: [WindowAction: Shortcut], availability: WindowActionAvailability,
                      controller: WindowActionController) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        for group in WindowActionGroup.all {
            for windowAction in group.menuActions {
                let item = NSMenuItem(title: L("app.action.\(windowAction.rawValue)"),
                                      action: #selector(WindowActionController.performMenuItem(_:)),
                                      keyEquivalent: "")
                item.target = controller
                item.representedObject = windowAction
                item.image = windowAction.menuImage
                if let shortcut = shortcuts[windowAction], let key = shortcut.menuKeyEquivalent {
                    item.keyEquivalent = key
                    item.keyEquivalentModifierMask = shortcut.menuModifierMask
                }
                item.isEnabled = availability.isEnabled(windowAction)
                items.append(item)
            }
            items.append(.separator())
        }
        return items
    }
}

extension WindowActionMenu {
    /// Fills the Status Menu with `items`. Auto-enabling is off because AppKit would otherwise turn
    /// every Window Action back on when the menu opens: the items carry their own enabled state.
    static func replaceItems(of menu: NSMenu, with items: [NSMenuItem]) {
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items {
            item.keepImageVisible()
            menu.addItem(item)
        }
    }
}

extension WindowActionController {
    /// The Status Menu items' action: a click runs the same path as the item's Shortcut.
    @objc func performMenuItem(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        perform(action)
    }
}

extension WindowAction {
    var menuImage: NSImage? {
        switch self {
        case .leftHalf: symbol("rectangle.lefthalf.filled")
        case .rightHalf: symbol("rectangle.righthalf.filled")
        case .topHalf: symbol("rectangle.tophalf.filled")
        case .bottomHalf: symbol("rectangle.bottomhalf.filled")
        case .upperLeft: symbol("rectangle.inset.topleft.filled")
        case .upperRight: symbol("rectangle.inset.topright.filled")
        case .lowerLeft: symbol("rectangle.inset.bottomleft.filled")
        case .lowerRight: symbol("rectangle.inset.bottomright.filled")
        case .previousThird: symbol("rectangle.leadingthird.inset.filled")
        case .nextThird: symbol("rectangle.trailingthird.inset.filled")
        case .leftThird: Self.columns(0..<1)
        case .centerThird: Self.columns(1..<2)
        case .rightThird: Self.columns(2..<3)
        case .leftTwoThirds: Self.columns(0..<2)
        case .centerTwoThirds: Self.centeredTwoThirds
        case .rightTwoThirds: Self.columns(1..<3)
        case .center: symbol("rectangle.center.inset.filled")
        case .fullscreen: symbol("rectangle.inset.filled")
        case .makeLarger: symbol("arrow.up.left.and.arrow.down.right")
        case .makeSmaller: symbol("arrow.down.right.and.arrow.up.left")
        case .nextDisplay: symbol("rectangle.righthalf.inset.filled.arrow.right")
        case .previousDisplay: symbol("rectangle.lefthalf.inset.filled.arrow.left")
        case .undo: symbol("arrow.uturn.backward")
        case .redo: symbol("arrow.uturn.forward")
        }
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    /// SF Symbols has no icon for a center third or any two thirds, so the fixed thirds draw their
    /// own, sized to the 12 by 9.5 pt a menu draws `rectangle.inset.filled` at, so they line up.
    private static func columns(_ span: Range<Int>) -> NSImage {
        tile { inner in
            let gap: CGFloat = 0.6, column = (inner.width - 2 * gap) / 3
            return NSRect(x: inner.minX + CGFloat(span.lowerBound) * (column + gap), y: inner.minY,
                          width: CGFloat(span.count) * column + CGFloat(span.count - 1) * gap, height: inner.height)
        }
    }

    private static var centeredTwoThirds: NSImage {
        tile { inner in
            let gap: CGFloat = 0.6, width = 2 * (inner.width - 2 * gap) / 3 + gap
            return NSRect(x: inner.midX - width / 2, y: inner.minY, width: width, height: inner.height)
        }
    }

    private static func tile(fill: @escaping (NSRect) -> NSRect) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 14), flipped: false) { _ in
            let outer = NSRect(x: 3, y: 2.25, width: 12, height: 9.5)
            let outline = NSBezierPath(roundedRect: outer.insetBy(dx: 0.45, dy: 0.45), xRadius: 2.1, yRadius: 2.1)
            outline.lineWidth = 0.9
            NSColor.black.set()
            outline.stroke()
            NSBezierPath(roundedRect: fill(outer.insetBy(dx: 1.75, dy: 1.75)), xRadius: 0.8, yRadius: 0.8).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

extension NSMenuItem {
    /// macOS 27 hides menu item images unless the item asks for `preferredImageVisibility = .visible`.
    /// Set by key because the release runner builds with the macOS 26 SDK, which lacks the property.
    func keepImageVisible() {
        guard responds(to: Selector(("setPreferredImageVisibility:"))) else { return }
        setValue(1, forKey: "preferredImageVisibility")
    }
}

extension Shortcut {
    /// The menu item key equivalent for this key, or nil when it has no character a menu can show.
    var menuKeyEquivalent: String? {
        func functionKey(_ code: Int) -> String { String(utf16CodeUnits: [unichar(code)], count: 1) }
        switch keyLabel {
        case "←": return functionKey(NSLeftArrowFunctionKey)
        case "→": return functionKey(NSRightArrowFunctionKey)
        case "↓": return functionKey(NSDownArrowFunctionKey)
        case "↑": return functionKey(NSUpArrowFunctionKey)
        case "↩": return "\r"
        case "⇥": return "\t"
        case "Space": return " "
        case "⌫": return "\u{8}"
        case "⎋": return "\u{1b}"
        case let label where label.count == 1: return label.lowercased()
        default: return nil
        }
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }
}
