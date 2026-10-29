#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Spectacle 2 — local debug build. Per the dragon-mac-ops convention the debug build gets its
# OWN identity ("Spectacle 2 Debug" / a .debug bundle id) so its TCC (Accessibility) grant and
# settings never collide with an installed release copy (brew install --cask ...).
APP_NAME="Spectacle 2 Debug"
BIN_NAME="Spectacle2"                 # SwiftPM product name (what `swift build` produces)
# The executable *inside* the bundle is renamed to match the app, so Activity Monitor, `ps`, and
# the pkill below can tell this build apart from the installed release copy — both used to be
# called "Spectacle2", which meant this script's pkill also killed the user's release app.
EXEC_NAME="Spectacle 2 Debug"
DEBUG_ID="com.dragonapp.spectacle-2.debug"
# A stable self-signed identity of this exact name (Keychain Access → Certificate Assistant →
# Create a Certificate → type "Code Signing") makes the Accessibility grant persist across
# rebuilds. Without it we fall back to ad-hoc, which re-prompts each build.
SIGN_IDENTITY="Spectacle 2 Debug"
# Where the bundle inputs are READ from. DragonKit CONFORMANCE §R16 puts Info.plist and
# AppIcon.icns in App/ at the repo root — capital A, in every Dragon app whatever builds it —
# while Package.swift stays here, so `cd`-ing to the repo root is no longer enough to find them.
# One variable rather than the path repeated at each read: the two files moved together and the
# next thing §R16 adds (an entitlements file) will be read from the same place. release.yml
# passes the same directory to dragon-release-ci as swiftpm_bundle_inputs_directory, so the
# debug bundle and the released one are assembled from exactly these files.
INPUTS="App"

swift build -c debug
BIN_DIR="$(swift build -c debug --show-bin-path)"

APP="$BIN_DIR/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/$BIN_NAME" "$APP/Contents/MacOS/$EXEC_NAME"
cp "$INPUTS/Info.plist" "$APP/Contents/Info.plist"

# Re-id the main bundle to the .debug identity so it runs safely beside an installed release.
PB=/usr/libexec/PlistBuddy
"$PB" -c "Set :CFBundleIdentifier $DEBUG_ID" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist" 2>/dev/null \
  || "$PB" -c "Add :CFBundleDisplayName string $APP_NAME" "$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleExecutable $EXEC_NAME" "$APP/Contents/Info.plist" 2>/dev/null \
  || "$PB" -c "Add :CFBundleExecutable string $EXEC_NAME" "$APP/Contents/Info.plist"

# Build number = git commit count (monotonic) so About shows a real per-build number.
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
"$PB" -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist" 2>/dev/null \
  || "$PB" -c "Add :CFBundleVersion string $BUILD" "$APP/Contents/Info.plist"

# The commit's own timestamp, stamped beside the build number so both halves of About's version
# line describe the SAME commit: `v2.4.2 (762) · 2026-Aug-08 05:17:28 UTC`. DragonAbout reads
# this key and shows no timestamp at all when it is missing — there is deliberately no fallback
# to the executable's mtime, which is what the line used to mean and what drifted.
COMMIT_DATE="$(git log -1 --format=%cI 2>/dev/null || true)"
if [ -n "$COMMIT_DATE" ]; then
  "$PB" -c "Set :DragonCommitDate $COMMIT_DATE" "$APP/Contents/Info.plist" 2>/dev/null \
    || "$PB" -c "Add :DragonCommitDate string $COMMIT_DATE" "$APP/Contents/Info.plist"
fi

# The version field stays the numeric candidate for the next public release. This script used to
# append " (Debug)" to it, reasoning that the version is what gets read off a screenshot — right
# problem, wrong field. MAC-APP-RELEASE-LIFECYCLE.md makes CFBundleShortVersionString the sole
# source of truth for the app's semantic version and forbids a channel label inside it; release.yml
# runs with `assert_tag_matches_plist: true`, so that field is exactly what a `vX.Y.Z` tag is
# compared against. Assert it rather than trust it: clipmenu-2 and ice-2 had grown the same
# mutation, so the shape is one a debug script drifts back into.
SHORT="$("$PB" -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
if [[ ! "$SHORT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: CFBundleShortVersionString must be a numeric X.Y.Z candidate, got '$SHORT'" >&2
  exit 1
fi

# The word "Debug" lives here instead, as build-channel metadata. DragonAbout (kit 3.3.0+) reads
# this key and renders "v$SHORT Debug ($BUILD)", so the build is still identifiable from a
# screenshot or a bug report — what the version mutation above was reaching for — without the
# version field ever carrying a non-numeric value.
"$PB" -c "Set :DragonBuildChannel Debug" "$APP/Contents/Info.plist" 2>/dev/null \
  || "$PB" -c "Add :DragonBuildChannel string Debug" "$APP/Contents/Info.plist"

# Belt and braces with AppDelegate's `isDebugBuild()` guard, which withholds the menu's route into
# Sparkle: this makes the plist say so too, so no scheduled check against the production appcast
# can start even if that guard is ever removed. The repo Info.plist already ships false; stamped
# unconditionally so the guarantee does not depend on it staying that way.
"$PB" -c "Set :SUEnableAutomaticChecks false" "$APP/Contents/Info.plist" 2>/dev/null \
  || "$PB" -c "Add :SUEnableAutomaticChecks bool false" "$APP/Contents/Info.plist"

# And drop the production feed outright — this, not the toggle above, is what makes the remaining
# routes inert, and it is the one that closes the Updates *pane*. The pane stays in the sidebar
# because its position is DragonKit canon (CONFORMANCE §R9), so removing it is not on the table;
# instead it is disarmed at the data layer. `DragonUpdater` builds its `SPUUpdater` lazily and does
# `try instance.start()` (DragonKitUpdates/Updates.swift:144-166), which throws with no feed, so the
# property stays nil — `canCheckForUpdates` is `updater?.canCheckForUpdates ?? false` (:184) and the
# pane's button is `.disabled(!updater.canCheckForUpdates)` (:248). Toggle, button and menu item all
# go dead. yahoo-keykey-2 and ice-2 arrived at this independently; it is now the Dragon standard.
"$PB" -c "Delete :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || true

# Copy every SwiftPM resource bundle into Contents/Resources: DragonKit_DragonKit.bundle (the kit's
# strings) AND Spectacle2_Spectacle2.bundle (the app's own strings, resolved at runtime via
# LocalizationManager.appStringsBundle = AppResources.stringsBundle). Both lookups, and SwiftPM's
# own Bundle.module, check Bundle.main.resourceURL first; next to the binary they found nothing and
# the app trapped at launch.
cp -R "$BIN_DIR"/*.bundle "$APP/Contents/Resources/" 2>/dev/null || true

# App icon: CFBundleIconFile = "AppIcon" → macOS reads Contents/Resources/AppIcon.icns.
# The checked-in .icns is the build's input and lives in App/ with the plist (§R16); Icon/ holds
# the SOURCE ART that generates it (AppIcon-1024.png, make-appicon.swift) and is not a bundle
# input, so it did not move.
cp "$INPUTS/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Embed Sparkle.framework (linked by DragonKitUpdates) so the relocated .app finds it at
# runtime — SwiftPM otherwise leaves it in the artifacts dir, which the moved app can't reach.
SPARKLE_FW="$(find "$(pwd)/.build" -type d -name 'Sparkle.framework' -path '*macos*' 2>/dev/null | head -1)"
if [ -n "${SPARKLE_FW:-}" ]; then
  cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$EXEC_NAME" 2>/dev/null || true
fi

# Prefer the stable self-signed identity so Accessibility grants survive rebuilds; otherwise
# ad-hoc sign and tell the user how to make grants persist.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" >/dev/null 2>&1 \
    && echo "Signed with stable identity '$SIGN_IDENTITY' (grants persist across rebuilds)."
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "note: ad-hoc signed — macOS re-prompts for Accessibility after each rebuild."
  echo "      To persist grants, create a self-signed Code Signing certificate named"
  echo "      '$SIGN_IDENTITY' in Keychain Access (Certificate Assistant → Create a Certificate)."
fi

# Install into /Applications, where the release copy lives too, replacing the previous Debug copy
# outright. The rm -rf below runs in /Applications, so refuse unless the identity is the Debug one.
INSTALLED="/Applications/$APP_NAME.app"
[[ "$APP_NAME" == *" Debug" && "$DEBUG_ID" == *.debug ]] \
  || { echo "error: refusing to install a non-Debug identity into /Applications" >&2; exit 1; }

# Quit any previously-launched debug instance so a stale menu-bar icon doesn't linger. Found by the
# .debug bundle id, so it can never match the installed release app, and it also catches a Debug
# copy launched from an older build folder.
for ASN in $(lsappinfo find bundleid="$DEBUG_ID" | grep -oE 'ASN:0x[0-9a-f]+-0x[0-9a-f]+-' || true); do
  PID="$(lsappinfo info -only pid "$ASN" | grep -oE 'pid"? ?= ?[0-9]+' | grep -oE '[0-9]+$' || true)"
  [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
done
sleep 1

rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"
APP="$INSTALLED"
# -n forces a new instance of the bundle at exactly this path, rather than letting LaunchServices
# resolve the .debug id to some other copy it has seen.
open -n "$APP"

# Never report success without showing the identity actually shipped in the bundle.
echo
echo "Launched \"$APP_NAME\""
"$PB" -c 'Print :CFBundleIdentifier' -c 'Print :CFBundleName' -c 'Print :CFBundleDisplayName' \
      -c 'Print :CFBundleShortVersionString' -c 'Print :CFBundleVersion' \
      -c 'Print :DragonBuildChannel' -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist" \
  | paste -d' ' <(printf '  %s\n' 'id:' 'name:' 'displayName:' 'version:' 'build:' 'channel:' 'executable:') -
codesign --verify --deep --strict "$APP" 2>/dev/null \
  && echo "  signature:   OK" || echo "  signature:   FAILED"
echo "  path:        $APP"
echo
echo "Accessibility must be granted to \"$APP_NAME\" separately from the installed release copy."
