#!/bin/zsh
# Packs OptPaste.app into a compressed .dmg with the app icon on the volume and a drag-to-Applications layout.
#
#   scripts/make-dmg.sh path/to/OptPaste.app path/to/OptPaste.dmg
set -euo pipefail

app=${1:?usage: make-dmg.sh OptPaste.app OptPaste.dmg}
out=${2:?usage: make-dmg.sh OptPaste.app OptPaste.dmg}
name=OptPaste

work=$(mktemp -d)
trap 'hdiutil detach "$work/mnt" -quiet 2>/dev/null || true; rm -rf "$work"' EXIT

mkdir "$work/stage"
cp -R "$app" "$work/stage/"
ln -s /Applications "$work/stage/Applications"
cp "$app/Contents/Resources/AppIcon.icns" "$work/stage/.VolumeIcon.icns"

hdiutil create -quiet -volname "$name" -srcfolder "$work/stage" -fs HFS+ -format UDRW -ov "$work/rw.dmg"
mkdir "$work/mnt"
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$work/mnt" "$work/rw.dmg"

# Tells Finder the volume has a custom icon (.VolumeIcon.icns).
SetFile -a C "$work/mnt"

# Window layout is cosmetic; skip it if Finder can't be scripted here.
osascript <<EOF || echo "make-dmg: skipped Finder layout" >&2
tell application "Finder"
  set mountPoint to POSIX file "$work/mnt" as alias
  open mountPoint
  set win to container window of mountPoint
  set current view of win to icon view
  set toolbar visible of win to false
  set statusbar visible of win to false
  set bounds of win to {200, 120, 740, 460}
  set opts to icon view options of win
  set arrangement of opts to not arranged
  set icon size of opts to 112
  set position of item "$name.app" of mountPoint to {140, 150}
  set position of item "Applications" of mountPoint to {400, 150}
  close win
end tell
EOF

sync
hdiutil detach -quiet "$work/mnt"
hdiutil convert -quiet "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$out"
echo "$out"
