import SwiftUI
import DragonKit

/// The app's General pane — real, persisted settings bound to ``SettingsModel``.
struct GeneralPane: SettingsPane {
    let id = "general"
    let title = "app.pane.general"
    let systemImage = "gearshape"
    let model: SettingsModel

    var paneBody: some View { GeneralPaneView(model: model) }
}

private struct GeneralPaneView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        DragonForm {
            DragonSection(LocalizedStringKey(L("app.general.startup"))) {
                Toggle(L("app.general.launchAtLogin"), isOn: $model.launchAtLogin)
                    .dragonAnnotation(LocalizedStringKey(L("app.general.launchAtLoginHint")))
            }
            DragonSection(LocalizedStringKey(L("app.general.menuBar"))) {
                Toggle(L("app.general.showInMenuBar"), isOn: $model.showInMenuBar)
                    .dragonAnnotation(LocalizedStringKey(L("app.general.showInMenuBarHint")))
            }
            DragonSection(LocalizedStringKey(L("app.general.gaps"))) {
                Stepper(value: $model.gapSize, in: 0...100, step: 2) {
                    Text("\(L("app.general.gapSize")): \(Int(model.gapSize)) pt")
                }
                .dragonAnnotation(LocalizedStringKey(L("app.general.gapSizeHint")))
                Toggle(L("app.general.skipTopGap"), isOn: $model.skipGapTopEdge)
            }
            DragonSection(LocalizedStringKey(L("app.general.snapping"))) {
                Toggle(L("app.general.dragSnap"), isOn: $model.dragSnapEnabled)
                    .dragonAnnotation(LocalizedStringKey(L("app.general.dragSnapHint")))
            }
            // The shared language picker — every DragonKit app drops this in to get the
            // full 8-language switcher (live, no restart).
            DragonSection(LocalizedStringKey(L("app.general.languageSection"))) {
                LanguagePicker()
            }
        }
    }
}
