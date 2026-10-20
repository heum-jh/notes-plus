#!/bin/sh
# Usage: scripts/release.sh 0.2.0
# Sets the version in Info.plist, commits, tags vX.Y.Z, pushes, and publishes a GitHub Release
# with the zipped app and a Sparkle appcast.xml (the app reads releases/latest/download/appcast.xml).
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
REPO=heum-jh/notes-plus
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "usage: $0 X.Y.Z" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "v$VERSION already exists" >&2; exit 1; }

# Use the repo owner's account whichever gh login is active.
export GH_TOKEN="${GH_TOKEN:-$(gh auth token -u heum-jh)}"

BUILD=$(( $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" Info.plist
git commit -q -m "chore: v$VERSION 릴리스" Info.plist
git tag -a "v$VERSION" -m "v$VERSION"

# Release identity: `git config notesplus.releaseSignId` (a certificate without personal details), else ad-hoc.
# Keep it the same across releases, or users must re-grant Accessibility after updating.
SIGN_ID="${RELEASE_SIGN_ID:-$(git config notesplus.releaseSignId || echo -)}" scripts/build.sh
mkdir -p dist
ZIP="dist/NotesPlus-$VERSION.zip"
ditto -c -k --keepParent build/NotesPlus.app "$ZIP"

# EdDSA signature from the private key that `generate_keys --account notes-plus` stored in the login keychain.
SIGNATURE=$(.build/artifacts/sparkle/Sparkle/bin/sign_update --account notes-plus "$ZIP")
cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>NotesPlus</title>
    <item>
      <title>v$VERSION</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$REPO/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/NotesPlus-$VERSION.zip" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML

git push origin HEAD "v$VERSION"
gh release create "v$VERSION" "$ZIP" dist/appcast.xml --repo "$REPO" --title "v$VERSION" --generate-notes
scripts/build.sh >/dev/null  # Rebuild with the local identity so the running copy keeps its Accessibility grant.
