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
            // 2.6.0: Russian, and the fixes from issues #53 to #75. `.added` leads because Russian is
            // the one new thing; the fixes follow, grouped by what a user notices (settings,
            // shortcuts, windows off screen, overlap, gaps) rather than one line per issue.
            // `.changed` holds what moves on purpose: drag-to-snap matching the keyboard tiles,
            // the 1 or 2 pt shifts, and the DragonKit bump that brings Russian.
            sections: [
                ChangeSection(kind: .added, entries: [
                    L("app.whatsNew.added1"),
                ]),
                ChangeSection(kind: .fixed, entries: [
                    L("app.whatsNew.fixed1"),
                    L("app.whatsNew.fixed2"),
                    L("app.whatsNew.fixed3"),
                    L("app.whatsNew.fixed4"),
                    L("app.whatsNew.fixed5"),
                    L("app.whatsNew.fixed6"),
                ]),
                ChangeSection(kind: .changed, entries: [
                    L("app.whatsNew.changed1"),
                    L("app.whatsNew.changed2"),
                ]),
            ]
        )
    }
}
