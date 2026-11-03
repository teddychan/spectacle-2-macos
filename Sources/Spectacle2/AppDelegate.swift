import AppKit
import ApplicationServices
import SwiftUI
import DragonKit
import DragonKitUpdates
import SpectacleCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appName = AppIdentity.displayName
    private var bundleID: String { Bundle.main.bundleIdentifier ?? AppIdentity.releaseBundleID }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private let model = SettingsModel()
    private let updater = DragonUpdater()
    private var statusItem: NSStatusItem?
    private let shortcutStore = ShortcutStore(suiteName: SettingsModel.suiteName)
    private let windowActions = WindowActionController()
    private var dragSnap: DragSnapController?

    // Host-owned selection: the AppDelegate can set the pane before showing the window (so
    // the menu-bar "About" item lands on the About pane), which is why this uses
    // `SettingsShell` rather than self-owned `ManagedSettingsShell`.
    private let selection = SpectacleSettingsSelection()

    private lazy var settingsController: DragonSettingsWindowController = {
        if selection.paneID == nil { selection.paneID = "general" }
        return DragonSettingsWindowController(
            title: "\(appName) Settings",
            rootView: SpectacleSettingsRoot(
                appName: appName,
                panesBuilder: { [weak self] in self?.settingsPanes ?? [] },
                selection: selection
            )
        )
    }()

    // Sidebar order (host-owned): General → Shortcuts → Permissions → Sync & Backup →
    // What's New → Updates → About → Uninstall.
    private var settingsPanes: [AnySettingsPane] {
        [
            AnySettingsPane(GeneralPane(model: model)),
            AnySettingsPane(ShortcutsPane(store: shortcutStore, onChange: { [windowActions] map in
                windowActions.updateShortcuts(map)
            })),
            AnySettingsPane(PermissionsSettingsPane(permissions: [.accessibility()])),
            AnySettingsPane(BackupSettingsPane(config: backupConfig)),
            AnySettingsPane(WhatsNewSettingsPane(content: WhatsNewConfig.content)),
            AnySettingsPane(UpdatesSettingsPane(updater: updater)),
            AnySettingsPane(AboutSettingsPane(content: AboutConfig.content)),
            AnySettingsPane(UninstallSettingsPane(config: uninstallConfig, onCancel: { [selection] in
                selection.paneID = "general"
            })),
        ]
    }

    private var backupConfig: BackupConfig {
        BackupConfig(
            appName: appName,
            suiteName: SettingsModel.suiteName,
            appVersion: appVersion,
            relaunch: { [weak self] in self?.relaunch() }
        )
    }

    private var uninstallConfig: UninstallConfig {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
        return UninstallConfig(
            appName: appName,
            bundleID: bundleID,
            suiteNames: [SettingsModel.suiteName],
            checklistItems: [
                L("app.uninstall.item.app"),
                L("app.uninstall.item.settings"),
                L("app.uninstall.item.state"),
            ],
            optionalDataToggle: (
                label: L("app.uninstall.optionalData"),
                paths: [library.appending(path: "Application Support/\(appName)")]
            ),
            extraCleanupPaths: [
                library.appending(path: "Caches/\(bundleID)"),
                library.appending(path: "HTTPStorages/\(bundleID)"),
            ],
            // The *raw* identifier, never `bundleID` above: that one falls back to the release id
            // so a build which can't state its own still cleans a sensible domain, which is
            // harmless there and authorises a delete of the installed release here. See
            // `AppIdentity.homebrewCaskToken(actual:)`.
            homebrewCask: AppIdentity.homebrewCaskToken()
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Resolve the app's own Localizable.strings from its SwiftPM resource bundle (packaged
        // at Contents/Resources), which .module misses in a signed .app. See AppResources.
        LocalizationManager.shared.appStringsBundle = AppResources.stringsBundle

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Per-bundle-id autosave name so debug/release builds don't pollute each other's
        // menu-bar visibility store.
        item.autosaveName = "Spectacle2StatusItem-\(bundleID)"
        item.button?.image = menuBarIcon()

        // A delegate-owned menu so it can be rebuilt on every open — that keeps its titles in the
        // current language and lets the Accessibility warning appear/disappear as permission changes.
        let menu = NSMenu()
        menu.delegate = self
        // The Window Action items set their own enabled state from the Target Window and displays.
        menu.autoenablesItems = false
        item.menu = menu
        item.isVisible = model.showInMenuBar
        self.statusItem = item

        // Settings side effects this delegate owns outright: it created `model`, and it owns both
        // the status item and the drag-snap controller, so they arrive as typed direct calls.
        model.onShowInMenuBarChange = { [weak self] visible in
            self?.statusItem?.isVisible = visible
        }
        model.onDragSnapEnabledChange = { [weak self] enabled in
            if enabled { self?.dragSnap?.start() } else { self?.dragSnap?.stop() }
        }
        // Suspend global hot keys while a shortcut recorder is capturing (see setRecording). This
        // one stays a notification: it is posted by an NSView buried inside the settings pane
        // tree, which has no ownership path back to here.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingChanged(_:)),
            name: .spectacleShortcutRecordingChanged,
            object: nil
        )
        // Self-heal drag-snap when the app becomes active. On a fresh install the user often grants
        // Accessibility *after* launch; DragSnapController.start() no-ops while untrusted, so re-run
        // it on activation (idempotent) to install the monitors once permission lands — no restart.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
        // Menu titles switch language live because the delegate rebuilds the menu on every open.

        // Never trap the user: if the icon is hidden at launch, open Settings so they can
        // toggle it back on.
        if !model.showInMenuBar {
            settingsController.show()
        }

        windowActions.gapProvider = { [model] in
            (CGFloat(model.gapSize), model.skipGapTopEdge)
        }

        // Register the 18 global hot keys after the first runloop tick so 18 synchronous Carbon
        // RegisterEventHotKey calls don't block applicationDidFinishLaunching returning. A hot key
        // pressed in the first few ms simply won't fire yet — acceptable.
        let map = shortcutStore.load()
        DispatchQueue.main.async { [windowActions, model] in
            windowActions.start(with: map)
            let snap = DragSnapController(
                controller: windowActions,
                gapProvider: { [model] in WindowGap(size: CGFloat(model.gapSize), skipTopEdge: model.skipGapTopEdge) }
            )
            if model.dragSnapEnabled { snap.start() }
            self.dragSnap = snap
        }
    }

    /// The menu-bar status-item image: a simple line-art of the Spectacle glasses, drawn as a
    /// monochrome **template** so macOS tints it correctly for light/dark menu bars (the same
    /// minimalist treatment ClipMenu uses). Vector-drawn so it stays crisp at any scale.
    private func menuBarIcon() -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            // Glasses bounding box, inset so the temple arms stay inside the canvas.
            let g = NSRect(x: side * 0.14, y: side * 0.34, width: side * 0.72, height: side * 0.30)
            func X(_ f: CGFloat) -> CGFloat { g.minX + g.width * f }
            func Y(_ f: CGFloat) -> CGFloat { g.minY + g.height * f }
            let lw = side * 0.085
            NSColor.black.setStroke()
            let lensW = g.width * 0.40, r = g.height * 0.34
            for lx in [CGFloat(0.0), 0.60] {
                let lens = NSBezierPath(roundedRect: NSRect(x: X(lx), y: g.minY, width: lensW, height: g.height),
                                        xRadius: r, yRadius: r)
                lens.lineWidth = lw; lens.lineJoinStyle = .round; lens.stroke()
            }
            let bridge = NSBezierPath()
            bridge.move(to: NSPoint(x: X(0.40), y: Y(0.72)))
            bridge.curve(to: NSPoint(x: X(0.60), y: Y(0.72)),
                         controlPoint1: NSPoint(x: X(0.46), y: Y(1.02)),
                         controlPoint2: NSPoint(x: X(0.54), y: Y(1.02)))
            bridge.lineWidth = lw; bridge.lineCapStyle = .round; bridge.stroke()
            for (sx, ex) in [(CGFloat(0.02), CGFloat(-0.12)), (0.98, 1.12)] {
                let t = NSBezierPath()
                t.move(to: NSPoint(x: X(sx), y: Y(0.74)))
                t.line(to: NSPoint(x: X(ex), y: Y(0.98)))
                t.lineWidth = lw; t.lineCapStyle = .round; t.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Build the canonical Dragon menu-bar menu via `DragonAppMenu` — the single source of
    /// truth for order, naming, and leading SF Symbol, shared across every Dragon app. Rebuilt
    /// on language change. Uninstall is deliberately not here: it's a rare destructive action
    /// and lives in Settings as `UninstallSettingsPane` (see `settingsPanes`).
    private func buildMenu() -> NSMenu {
        // A Debug build passes `onCheckForUpdates: nil`, which drops the item from the dropdown
        // entirely — the same mechanism a Mac App Store build uses. MAC-APP-RELEASE-LIFECYCLE.md
        // requires the local build to never read the production appcast, and an item left in place
        // but made inert reads as a bug: the Debug build should have no route to that feed, not a
        // route that silently does nothing. `SUEnableAutomaticChecks = false` is not the off switch
        // on its own — `DragonUpdater` builds its `SPUUpdater` lazily on first use, so it is the
        // *invocation* that has to be withheld.
        DragonAppMenu.menu(DragonAppMenu.Config(
            appName: appName,
            onAbout: { [weak self] in self?.openAbout() },
            onSettings: { [weak self] in self?.openSettings() },
            onCheckForUpdates: DragonAbout.isDebugBuild()
                ? nil
                : { [weak self] in self?.checkForUpdates() }
        ))
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func openPermissions() {
        selection.paneID = "permissions"
        settingsController.show()
    }

    @objc private func checkForUpdates() {
        selection.paneID = "updates"
        settingsController.show()
        updater.checkForUpdates()
    }

    @objc private func openAbout() {
        selection.paneID = "about"
        settingsController.show()
    }

    /// Re-arm drag-snap whenever the app becomes active. `start()` is idempotent and no-ops until
    /// Accessibility is trusted, so this quietly installs the monitors the first time the user
    /// returns after granting permission — no restart or toggle needed.
    @objc private func appDidBecomeActive() {
        if model.dragSnapEnabled { dragSnap?.start() }
    }

    @objc private func shortcutRecordingChanged(_ note: Notification) {
        windowActions.setRecording((note.object as? Bool) ?? false)
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Rebuilds the status-item menu just before it opens: the Window Actions with their current
    /// Shortcuts, then fresh (current-language) items from the canonical `DragonAppMenu`, topped
    /// with an Accessibility-access warning whenever the permission is missing — so a user whose
    /// hot keys do nothing has a visible way to fix it.
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Opening the menu is the most frequent interaction with a menu-bar-only app, so use it as
        // a second self-heal trigger: re-arm drag-snap here too (idempotent) in case the user
        // granted Accessibility directly in System Settings without returning to a window.
        if model.dragSnapEnabled { dragSnap?.start() }
        menu.removeAllItems()
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let warn = NSMenuItem(title: L("app.menu.accessibilityNeeded"),
                                  action: #selector(openPermissions), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }
        let availability = WindowActionAvailability(
            isTrusted: trusted, hasTargetWindow: windowActions.hasTargetWindow, displayCount: NSScreen.screens.count)
        for item in WindowActionMenu.items(shortcuts: shortcutStore.load(), availability: availability,
                                           controller: windowActions) {
            menu.addItem(item)
        }
        let base = buildMenu()
        for item in base.items {
            base.removeItem(item)
            menu.addItem(item)
        }
    }
}

/// Host-owned settings selection. The AppDelegate sets `paneID` before showing the window,
/// so the menu can open directly to a specific pane (e.g. About) — including on first open.
@MainActor
@Observable
final class SpectacleSettingsSelection {
    var paneID: String?
}

/// Settings root wired to the host's ``SpectacleSettingsSelection``. Observes
/// ``LocalizationManager`` and rebuilds the panes whenever the language changes, then applies
/// `.dragonLocalized()` so the whole window switches language live — without a restart.
private struct SpectacleSettingsRoot: View {
    @ObservedObject private var localization = LocalizationManager.shared
    let appName: String
    let panesBuilder: () -> [AnySettingsPane]
    let selection: SpectacleSettingsSelection

    var body: some View {
        SettingsPaneList(appName: appName, panes: panesBuilder(), selection: selection)
            .dragonLocalized()
    }
}

/// Holds the (language-stable) pane list and binds selection, so switching panes re-renders
/// the sidebar/detail without rebuilding every pane.
private struct SettingsPaneList: View {
    let appName: String
    let panes: [AnySettingsPane]
    @Bindable var selection: SpectacleSettingsSelection

    var body: some View {
        SettingsShell(appName: appName, panes: panes, selection: $selection.paneID)
    }
}
