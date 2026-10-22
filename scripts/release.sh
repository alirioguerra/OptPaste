#!/bin/zsh
# Ships a new OptPaste version: bumps the version, builds the .dmg, publishes it on the site
# (public/downloads + latest.json), tags the app repo and creates the GitHub release.
#
#   scripts/release.sh 1.0.0-beta.2
#
# Release notes are the feat/fix commit subjects since the previous tag.
set -euo pipefail

version=${1:?usage: release.sh <version>, e.g. 1.0.0-beta.2}
[[ $version =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$' ]] || { echo "invalid version: $version" >&2; exit 1; }
core=${version%%-*}
pre=${version#$core}; pre=${pre#-}

repo=${0:A:h:h}
site=${SITE_DIR:-$repo/../optpaste-site}
project=$repo/OptPaste.xcodeproj/project.pbxproj
cd "$repo"

[[ -z $(git status --porcelain --untracked-files=no) ]] || { echo "app repo has uncommitted changes" >&2; exit 1; }
[[ -z $(git -C "$site" status --porcelain --untracked-files=no) ]] || { echo "site repo has uncommitted changes" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && { echo "tag v$version already exists" >&2; exit 1; }

previous=$(git describe --tags --abbrev=0 2>/dev/null || true)
notes=$(git log --no-merges --format='- %s' ${previous:+$previous..}HEAD | grep -E '^- (feat|fix)(\(.+\))?!?: ' || true)
[[ -n $notes ]] || notes='- Maintenance release'

# Version: numeric core in the project, pre-release label in UpdateChecker.
build=$(( $(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+' "$project" | grep -oE '[0-9]+$') + 1 ))
sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $core;/; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $build;/" "$project"
if [[ -n $pre ]]; then label="\"$pre\""; else label=nil; fi
sed -i '' -E "s/static let prerelease: String\? = .*/static let prerelease: String? = $label/" OptPaste/UpdateChecker.swift

xcodebuild -scheme OptPaste -configuration Release -derivedDataPath build/DerivedData build -quiet
"$repo/scripts/make-dmg.sh" build/DerivedData/Build/Products/Release/OptPaste.app "$site/public/downloads/OptPaste.dmg"

prerelease=false; [[ -n $pre ]] && prerelease=true
cat > "$site/public/latest.json" <<EOF
{
  "version": "$version",
  "prerelease": $prerelease,
  "url": "https://optpaste-site.vercel.app/downloads/OptPaste.dmg"
}
EOF

message="chore: release v$version

$notes"
git add "$project" OptPaste/UpdateChecker.swift
git commit -q -m "$message"
git tag -a "v$version" -m "OptPaste $version" -m "$notes"
git push -q origin HEAD "v$version"

git -C "$site" add public/downloads/OptPaste.dmg public/latest.json
git -C "$site" commit -q -m "$message"
git -C "$site" push -q origin HEAD

if command -v gh >/dev/null; then
  gh release create "v$version" "$site/public/downloads/OptPaste.dmg" \
    --title "OptPaste $version" --notes "$notes" ${pre:+--prerelease}
else
  echo "gh not installed: tag v$version pushed, GitHub release not created" >&2
fi

echo "Released $version"
echo "$notes"
