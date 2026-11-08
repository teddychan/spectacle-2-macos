import Foundation
import DragonKit

enum WhatsNewConfig {
    @MainActor
    static var content: WhatsNewContent {
        WhatsNewContent(
            // `version` is omitted deliberately: it defaults to the bundle's
            // `CFBundleShortVersionString` and the kit adds the `v`, so What's New tracks the
            // shipped release without a second edit. Pass one only to pin notes to an older release.
            date: "2026-11-08",
            summary: L("app.whatsNew.summary"),
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.changed1"),
                ]),
            ]
        )
    }
}
