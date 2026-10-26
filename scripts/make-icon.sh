#!/bin/zsh
# Draws the app icon (scripts/make-icon.swift) and writes every size macOS needs into AppIcon.appiconset.
set -euo pipefail
cd "$(dirname "$0")/.."
set_dir=Gota/Resources/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)
swiftc scripts/make-icon.swift -o "$tmp/make-icon"
"$tmp/make-icon" "$tmp/icon-1024.png"
mkdir -p "$set_dir"
images=()
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    name="icon_${size}x${size}@${scale}x.png"
    sips -z $px $px "$tmp/icon-1024.png" --out "$set_dir/$name" >/dev/null
    images+=("{\"size\":\"${size}x${size}\",\"idiom\":\"mac\",\"filename\":\"$name\",\"scale\":\"${scale}x\"}")
  done
done
printf '{"images":[%s],"info":{"version":1,"author":"xcode"}}\n' "${(j:,:)images}" > "$set_dir/Contents.json"
printf '{"info":{"version":1,"author":"xcode"}}\n' > Gota/Resources/Assets.xcassets/Contents.json
rm -rf "$tmp"
echo "Icon written to $set_dir"
