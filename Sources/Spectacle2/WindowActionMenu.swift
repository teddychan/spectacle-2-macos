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
