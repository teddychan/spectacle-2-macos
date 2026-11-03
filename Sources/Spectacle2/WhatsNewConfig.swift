import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-11-03",
            summary: L("app.whatsNew.summary"),
            // 2.7.0: the window actions in the menu bar menu, the release's one change.
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                ]),
            ]
        )
    }
}
