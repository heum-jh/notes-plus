#!/bin/sh
# Builds build/NotesPlus.app. A stable signing identity keeps the Accessibility grant across rebuilds;
# without one (other machines), it falls back to ad-hoc signing and the grant resets on every build.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/NotesPlus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NotesPlus "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
SIGN_ID="${SIGN_ID:-7B8A937D3850CD20EE12E213C3AEEA7203243436}"
security find-identity -v -p codesigning | grep -q "$SIGN_ID" || SIGN_ID=-
codesign --force --sign "$SIGN_ID" "$APP"
echo "$APP"
