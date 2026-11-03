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
            // 2.8.1: only the DragonKit 4.3.0 move. Its menu icon fix changes nothing here, since
            // 2.7.0 already kept every Status Menu icon visible on macOS 27.
            sections: [
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
