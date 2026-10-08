// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Spectacle2",
    defaultLocalization: "en",
    platforms: [.macOS("26")],
    dependencies: [
        // Direct-download app → link BOTH DragonKit and DragonKitUpdates (Sparkle).
        //
        // `from:`, not `exact:` — the Dragon apps state the kit pin one way, and this app was the
        // last one still on `exact:`. clipmenu-2 and dragon-sample-app write `from:` literally;
        // ice-2's .pbxproj spells the same range as `upToNextMajorVersion` with a `minimumVersion`;
        // yahoo-keykey-2 cannot express it at all — its package takes the kit as
        // `.package(path: "../../vendor/dragon-kit")` and the real pin is the `DRAGONKIT_TAG` clone
        // in `tools/build-app.sh`.
        //
        // Deliberately no version numbers for any of those, and please don't add any back. They
        // bump on their own schedule and nothing in this file can notice when they do, so a number
        // written here to illustrate a *form* is stale by construction. It already was: this
        // comment claimed `3.2.0` for clipmenu-2 and ice-2 while both had moved to 3.4.0, which
        // read as if this app were pinned differently from its siblings when it wasn't. The form
        // is the durable fact; the version belongs only on the `.package` line below, where SwiftPM
        // and the R10 conformance check both read it.
        //
        // The tradeoff lands harder here than on the others: Package.resolved is gitignored
        // in this repo, while they commit theirs and are therefore locked to a resolved revision.
        // Every CI build here resolves from scratch, so any kit tag inside the pinned major that
        // is published before the next release floats into that release with nobody having run the
        // app against it. (Stated as a range rather than "a 3.x tag", which this comment used to
        // say and which went stale the moment the pin moved to 4.0.0.) That is the
        // accepted price of the unified pin form, not an oversight — which is why a kit bump still
        // wants a deliberate build-and-run check, on the version that actually resolved, before a
        // release tag goes out.
        .package(url: "https://github.com/teddychan/dragon-kit", from: "4.2.0"),
    ],
    targets: [
        .target(name: "SpectacleCore"),
        .executableTarget(
            name: "Spectacle2",
            dependencies: [
                "SpectacleCore",
                .product(name: "DragonKit", package: "dragon-kit"),
                .product(name: "DragonKitUpdates", package: "dragon-kit"),
            ],
            // Bundle the app's own localizations (Resources/<lang>.lproj) into
            // Spectacle2_Spectacle2.bundle so both run.sh and the release CI ship them via
            // the standard SwiftPM resource-bundle copy. Resolved at runtime through
            // LocalizationManager.appStringsBundle = AppResources.stringsBundle (in AppDelegate).
            resources: [.process("Resources")],
            // Embed the rpath the release CI relies on to locate the bundled
            // Sparkle.framework at Contents/Frameworks/. Without this the packaged .app only
            // carries the default @loader_path rpath, so dyld looks for Sparkle in
            // Contents/MacOS/ and the app crashes on launch (Library not loaded: Sparkle).
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks"])
            ]
        ),
        .testTarget(name: "SpectacleCoreTests", dependencies: ["SpectacleCore"]),
        .testTarget(name: "Spectacle2Tests", dependencies: ["Spectacle2"]),
    ]
)
