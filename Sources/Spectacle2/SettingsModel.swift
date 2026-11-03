import Foundation
import DragonKit

/// Spectacle 2's persisted app settings. A plain `Codable` value stored in a named
/// UserDefaults suite via ``DragonSettingsStore`` — so Backup & Restore can snapshot and
/// restore it wholesale. The window-action shortcut map is added in a later feature commit;
/// this scaffold holds only the shell-level options.
struct AppSettings: Codable, Sendable, Equatable {
    var launchAtLogin = false
    var showInMenuBar = true
    var gapSize: Double = 0
    var skipGapTopEdge = false
    var dragSnapEnabled = true

    init() {}

    // Tolerant decoder: old payloads (only launchAtLogin/showInMenuBar) must decode cleanly, with
    // the new fields taking their defaults. Synthesized Decodable would throw on the missing keys
    // and reset everything (DragonSettingsStore.load falls back to defaultValue on any error).
    enum CodingKeys: String, CodingKey {
        case launchAtLogin, showInMenuBar, gapSize, skipGapTopEdge, dragSnapEnabled
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? true
        gapSize = try c.decodeIfPresent(Double.self, forKey: .gapSize) ?? 0
        skipGapTopEdge = try c.decodeIfPresent(Bool.self, forKey: .skipGapTopEdge) ?? false
        dragSnapEnabled = try c.decodeIfPresent(Bool.self, forKey: .dragSnapEnabled) ?? true
    }
}

extension Notification.Name {
    /// Posted (with a `Bool` object) while a shortcut recorder is capturing. The AppDelegate
    /// suspends the global hot keys during recording so pressing an already-bound combo lands in
    /// the recorder instead of firing that action, then restores them when recording ends.
    static let spectacleShortcutRecordingChanged = Notification.Name("spectacleShortcutRecordingChanged")
}

/// Observable bridge between the settings UI and persistence. Each setter persists via the
/// store and applies its side effect (login-item registration, menu-bar visibility).
@MainActor
@Observable
final class SettingsModel {
    /// A dedicated suite (distinct from the app's bundle-id domain) so a backup captures only
    /// app settings — not the backup pane's own preferences.
    static let suiteName = (Bundle.main.bundleIdentifier ?? "com.dragonapp.spectacle-2") + ".settings"

    private let store: DragonSettingsStore<AppSettings>
    private var settings: AppSettings {
        didSet { store.save(settings) }
    }

    /// Side effects owned by the composition root. `AppDelegate` creates this model and also owns
    /// the status item and the drag-snap controller, so these two settings reach them by direct
    /// call rather than through an ambient notification: the payload stays typed, and an
    /// unassigned hook is visible here instead of silently doing nothing.
    var onShowInMenuBarChange: ((Bool) -> Void)?
    var onDragSnapEnabledChange: ((Bool) -> Void)?

    init() {
        let store = Self.makeStore(suiteName: Self.suiteName)
        self.store = store
        self.settings = store.load()
        // Reconcile the OS login-item state off the launch critical path (SMAppService is a
        // synchronous ServiceManagement call). The persisted preference is unchanged.
        let enabled = settings.launchAtLogin
        DispatchQueue.main.async { LoginItem.setEnabled(enabled) }
    }

    /// The settings store, after taking the shortcut map out of its key so `load()` can't mistake
    /// it for unreadable settings. This runs before `ShortcutStore` exists, hence the call here.
    static func makeStore(suiteName: String) -> DragonSettingsStore<AppSettings> {
        ShortcutStore.migrateSharedKey(suiteName: suiteName)
        return DragonSettingsStore(suiteName: suiteName, defaultValue: AppSettings())
    }

    var launchAtLogin: Bool {
        get { settings.launchAtLogin }
        set {
            settings.launchAtLogin = newValue
            LoginItem.setEnabled(newValue)
        }
    }

    var showInMenuBar: Bool {
        get { settings.showInMenuBar }
        set {
            settings.showInMenuBar = newValue
            onShowInMenuBarChange?(newValue)
        }
    }

    var gapSize: Double {
        get { settings.gapSize }
        set { settings.gapSize = max(0, min(newValue, 100)) }   // sane clamp; recomputed per action
    }

    var skipGapTopEdge: Bool {
        get { settings.skipGapTopEdge }
        set { settings.skipGapTopEdge = newValue }
    }

    var dragSnapEnabled: Bool {
        get { settings.dragSnapEnabled }
        set {
            settings.dragSnapEnabled = newValue
            onDragSnapEnabledChange?(newValue)
        }
    }
}
