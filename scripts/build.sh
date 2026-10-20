#!/bin/sh
# Builds build/NotesPlus.app.
# Signing identity: $SIGN_ID, else `git config notesplus.signId` (kept local, never committed), else ad-hoc.
# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc builds need it re-granted each time.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/NotesPlus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/NotesPlus "$APP/Contents/MacOS/"
cp -R .build/release/Sparkle.framework "$APP/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/NotesPlus"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/"
SIGN_ID="${SIGN_ID:-$(git config notesplus.signId || echo -)}"
# --deep also signs Sparkle's embedded helpers (Autoupdate, Updater.app, XPC services).
codesign --force --deep --sign "$SIGN_ID" "$APP"
echo "$APP"
