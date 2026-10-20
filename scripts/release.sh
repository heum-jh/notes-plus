#!/bin/sh
# Usage: scripts/release.sh 0.2.0
# Sets the version in Info.plist, commits, tags vX.Y.Z, pushes, and publishes a GitHub Release with the zipped app.
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "usage: $0 X.Y.Z" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "v$VERSION already exists" >&2; exit 1; }

# The repo lives under heum-jh; use that account whichever gh login is active.
export GH_TOKEN="${GH_TOKEN:-$(gh auth token -u heum-jh)}"

BUILD=$(( $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" Info.plist
git commit -q -m "chore: v$VERSION 릴리스" Info.plist
git tag -a "v$VERSION" -m "v$VERSION"

# Ad-hoc signed so the published app carries no personal certificate.
SIGN_ID=- scripts/build.sh
mkdir -p dist
ZIP="dist/NotesPlus-$VERSION.zip"
ditto -c -k --keepParent build/NotesPlus.app "$ZIP"

git push origin HEAD "v$VERSION"
gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --generate-notes
scripts/build.sh >/dev/null  # Rebuild with the local identity so the running copy keeps its Accessibility grant.
