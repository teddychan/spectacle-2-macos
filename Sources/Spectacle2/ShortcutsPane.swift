import SwiftUI
import DragonKit
import SpectacleCore

struct ShortcutsPane: SettingsPane {
    let id = "shortcuts"
    let title = "app.pane.shortcuts"
    let systemImage = "keyboard"
    let store: ShortcutStore
    /// Applies the new map to the hot-key engine and returns the actions that failed to
    /// register (conflicts), which the pane flags on the affected rows.
    let onChange: (ShortcutStore.Map) -> Set<WindowAction>

    var paneBody: some View { ShortcutsPaneView(store: store, onChange: onChange) }
}

private struct ShortcutsPaneView: View {
    let store: ShortcutStore
    let onChange: (ShortcutStore.Map) -> Set<WindowAction>
    @State private var map: ShortcutStore.Map = [:]
    @State private var conflicts: Set<WindowAction> = []
    @State private var search = ""

    // Actions bound to a combo that another action is already using. Flagged independently of
    // the system-conflict set: Carbon only reports which registration lost the race (order-
    // dependent), so we detect the collision ourselves and flag *both* rows.
    private var duplicates: Set<WindowAction> {
        var byShortcut: [Shortcut: [WindowAction]] = [:]
        for (action, shortcut) in map { byShortcut[shortcut, default: []].append(action) }
        return Set(byShortcut.values.filter { $0.count > 1 }.joined())
    }

    var body: some View {
        DragonForm {
            DragonSection {
                TextField(L("app.shortcuts.search"), text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            ForEach(WindowActionGroup.all, id: \.titleKey) { section in
                let visible = section.actions.filter(matchesSearch)
                if !visible.isEmpty {
                    DragonSection(LocalizedStringKey(L(section.titleKey))) {
                        ForEach(visible, id: \.self) { action in
                            row(for: action)
                        }
                    }
                }
            }
            DragonSection {
                Button(L("app.shortcuts.restoreDefaults")) {
                    map = store.restoreDefaults()
                    conflicts = onChange(map)
                }
            }
        }
        .onAppear {
            map = store.load()
            conflicts = onChange(map)
        }
    }

    private func matchesSearch(_ action: WindowAction) -> Bool {
        search.isEmpty || L("app.action.\(action.rawValue)").localizedCaseInsensitiveContains(search)
    }

    @ViewBuilder
    private func row(for action: WindowAction) -> some View {
        let content = HStack {
            Text(L("app.action.\(action.rawValue)"))
            Spacer()
            ShortcutRecorderField(
                shortcut: Binding(
                    get: { map[action] },
                    set: { map[action] = $0 }
                ),
                onChange: { _ in
                    store.save(map)
                    conflicts = onChange(map)
                }
            )
            .frame(width: 200)
        }
        // Duplicate binding takes precedence: it's actionable by the user (rebind one), whereas a
        // system conflict is not.
        if duplicates.contains(action) {
            content.dragonAnnotation(LocalizedStringKey(L("app.shortcuts.duplicate")))
        } else if conflicts.contains(action) {
            content.dragonAnnotation(LocalizedStringKey(L("app.shortcuts.conflict")))
        } else {
            content
        }
    }
}
