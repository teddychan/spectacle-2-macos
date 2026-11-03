import AppKit
import DragonKit
import SpectacleCore

/// The Window Actions in display order, grouped the way Spectacle's preferences lay them out.
/// The Shortcuts pane's sections and the Status Menu's separated groups both read this table.
struct WindowActionGroup {
    let titleKey: String
    let actions: [WindowAction]

    static let all: [WindowActionGroup] = [
        WindowActionGroup(titleKey: "app.shortcuts.section.halves",
                          actions: [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        WindowActionGroup(titleKey: "app.shortcuts.section.corners",
                          actions: [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
        WindowActionGroup(titleKey: "app.shortcuts.section.thirds",
                          actions: [.nextThird, .previousThird]),
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
            for windowAction in group.actions {
                let item = NSMenuItem(title: L("app.action.\(windowAction.rawValue)"),
                                      action: #selector(WindowActionController.performMenuItem(_:)),
                                      keyEquivalent: "")
                item.target = controller
                item.representedObject = windowAction
                item.image = NSImage(systemSymbolName: windowAction.symbolName, accessibilityDescription: nil)
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

extension WindowActionController {
    /// The Status Menu items' action: a click runs the same path as the item's Shortcut.
    @objc func performMenuItem(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        perform(action)
    }
}

extension WindowAction {
    var symbolName: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .upperLeft: "rectangle.inset.topleft.filled"
        case .upperRight: "rectangle.inset.topright.filled"
        case .lowerLeft: "rectangle.inset.bottomleft.filled"
        case .lowerRight: "rectangle.inset.bottomright.filled"
        case .previousThird: "rectangle.leadingthird.inset.filled"
        case .nextThird: "rectangle.trailingthird.inset.filled"
        case .center: "rectangle.center.inset.filled"
        case .fullscreen: "rectangle.inset.filled"
        case .makeLarger: "arrow.up.left.and.arrow.down.right"
        case .makeSmaller: "arrow.down.right.and.arrow.up.left"
        case .nextDisplay: "rectangle.righthalf.inset.filled.arrow.right"
        case .previousDisplay: "rectangle.lefthalf.inset.filled.arrow.left"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        }
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
