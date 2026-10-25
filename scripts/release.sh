#!/bin/zsh
# Builds Gota in Release, packages it as a zip and (with --publish) creates the GitHub release.
#
#   scripts/release.sh             # build dist/Gota-<version>.zip and its SHA-256
#   scripts/release.sh --publish   # same, then tag v<version> and upload it to GitHub Releases
#
# The app is ad-hoc signed (no Apple Developer account): macOS asks to confirm the first launch.
# See docs/INSTALAR.md.
set -euo pipefail

cd "$(dirname "$0")/.."
version=$(awk -F'"' '/MARKETING_VERSION:/ {print $2}' project.yml)
[[ -n "$version" ]] || { echo "No MARKETING_VERSION in project.yml" >&2; exit 1; }

if [[ "${1:-}" == "--publish" && -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first: the release must match the tagged code." >&2
  exit 1
fi

echo "→ Building Gota $version (Release)"
xcodegen --quiet
rm -rf build dist
xcodebuild -scheme Gota -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build ONLY_ACTIVE_ARCH=NO build -quiet

app=build/Build/Products/Release/Gota.app
codesign --verify --strict "$app"

mkdir -p dist
zip="dist/Gota-$version.zip"
# ditto keeps the bundle's symlinks, permissions and signature intact (plain zip can break them).
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
# Written from inside dist/ so the file names just the zip: `shasum -c` then works in ~/Downloads.
(cd dist && shasum -a 256 "${zip:t}" | tee "${zip:t}.sha256")

if [[ "${1:-}" == "--publish" ]]; then
  echo "→ Publishing v$version"
  gh release create "v$version" "$zip" "$zip.sha256" \
    --title "Gota $version" \
    --notes-file docs/RELEASE-NOTES.md
fi
