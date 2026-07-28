#!/usr/bin/env bash
# Renames this AppTemplate clone into your own app: target/product name, folder names,
# TemplateApp.swift's @main struct, and every bundle identifier. Automates README's
# "Making it your app" step 1 — see README.md for the remaining manual steps (replace the
# Item domain model, wire AppDependencies, add app icons, set BASE_URL per environment).
#
# Usage:
#   Scripts/bootstrap-new-project.sh <NewName> [bundle-id-prefix] [--dry-run]
#
#   <NewName>          PascalCase, e.g. TaskFlow. Becomes the target/product name;
#                      AppTemplate/ -> TaskFlow/, AppTemplateTests/ -> TaskFlowTests/,
#                      TemplateApp.swift's @main struct -> TaskFlowApp.
#   bundle-id-prefix   Reverse-DNS prefix for the Prod build, e.g. com.mycompany.taskflow.
#                      Dev/QA get ".dev"/".qa" appended, matching the existing pattern.
#                      Default: com.yourcompany.<lowercased NewName>
#   --dry-run          Print what would change without touching anything.
#
# Deliberately NOT renamed — neither is asked for by README's own "Making it your app"
# text, and both are internal identifiers a fresh clone doesn't need to care about:
#   - The Xcode scheme names (AppTemplate-Dev/QA/Prod).
#   - project.yml's top-level `name:`, so the generated project stays
#     AppTemplate.xcodeproj. (Rename it by hand — one line in project.yml — if you want
#     the .xcodeproj file itself to match; nothing else depends on it.)
#
# Known gotcha: SwiftLint's sorted_imports rule may flag `@testable import <NewName>` as
# out of order in a test file or two afterward — whether <NewName> alphabetizes the same
# way "AppTemplate" did depends on the name you pick. `swiftlint lint --strict` will point
# at the exact line; swap it with its neighbor.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f project.yml ] || [ ! -d AppTemplate ]; then
  echo "error: run this from a fresh, unrenamed AppTemplate clone (expected ./project.yml and ./AppTemplate/)" >&2
  exit 1
fi

DRY_RUN=false
POSITIONAL=()
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  else
    POSITIONAL+=("$arg")
  fi
done

NEW_NAME="${POSITIONAL[0]:-}"
if [ -z "$NEW_NAME" ]; then
  echo "usage: $0 <NewName> [bundle-id-prefix] [--dry-run]" >&2
  exit 1
fi
if ! [[ "$NEW_NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  echo "error: <NewName> must be a valid PascalCase Swift identifier (e.g. TaskFlow) — got '$NEW_NAME'" >&2
  exit 1
fi
if [ -e "$NEW_NAME" ]; then
  echo "error: ./$NEW_NAME already exists — refusing to overwrite" >&2
  exit 1
fi

LOWER_NAME="$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')"
BUNDLE_ID_PREFIX="${POSITIONAL[1]:-com.yourcompany.$LOWER_NAME}"
if ! [[ "$BUNDLE_ID_PREFIX" =~ ^[a-z0-9]+(\.[a-z0-9]+)+$ ]]; then
  echo "error: bundle-id-prefix must be lowercase reverse-DNS (e.g. com.mycompany.taskflow) — got '$BUNDLE_ID_PREFIX'" >&2
  exit 1
fi

echo "Renaming AppTemplate -> $NEW_NAME"
echo "Bundle IDs: $BUNDLE_ID_PREFIX (.dev / .qa / .tests variants as today)"
if $DRY_RUN; then echo "(dry run — nothing will actually change)"; fi
echo

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# Every file whose *content* mentions the template's identity. Deliberately excludes
# README.md/CONTRIBUTING.md/LICENSE/.github — those are template documentation/CI prose,
# not source identifiers, and a real project typically replaces the README wholesale
# rather than having it mechanically renamed.
FILES_TO_EDIT=(
  project.yml
  .swiftlint.yml
  AppTemplate/Config/DevConfig.xcconfig
  AppTemplate/Config/QAConfig.xcconfig
  AppTemplate/Config/ProdConfig.xcconfig
)
while IFS= read -r f; do FILES_TO_EDIT+=("$f"); done < <(find AppTemplate AppTemplateTests -name '*.swift')

edit_file() {
  local file="$1"
  if $DRY_RUN; then
    local hits
    hits=$(grep -c "AppTemplate\|TemplateApp\|com\.yourcompany\.apptemplate" "$file" 2>/dev/null || true)
    if [ "${hits:-0}" != "0" ]; then
      echo "  [dry-run] would edit $file ($hits matching line(s))"
    fi
    return
  fi
  # Longest/most-specific bundle-id strings first so none is a partial match of another.
  sed -i '' \
    -e "s/com\.yourcompany\.apptemplate\.dev/${BUNDLE_ID_PREFIX}.dev/g" \
    -e "s/com\.yourcompany\.apptemplate\.qa/${BUNDLE_ID_PREFIX}.qa/g" \
    -e "s/com\.yourcompany\.apptemplate\.tests/${BUNDLE_ID_PREFIX}.tests/g" \
    -e "s/com\.yourcompany\.apptemplate/${BUNDLE_ID_PREFIX}/g" \
    -e "s/TemplateApp/${NEW_NAME}App/g" \
    -e "s/AppTemplate/${NEW_NAME}/g" \
    "$file"
}

echo "Editing source files..."
for f in "${FILES_TO_EDIT[@]}"; do
  edit_file "$f"
done

# project.yml's target key/PRODUCT_NAME/sources-path/dependency/scheme-target-refs all
# legitimately contain the substring "AppTemplate" and got renamed above along with
# everything else — but so did the top-level `name:` and the three scheme keys
# (AppTemplate-Dev/QA/Prod), which the blanket substitution can't tell apart from the
# renames that were actually wanted. Revert exactly those 4 lines back.
if ! $DRY_RUN; then
  sed -i '' \
    -e "s/^name: ${NEW_NAME}\$/name: AppTemplate/" \
    -e "s/^  ${NEW_NAME}-Dev:\$/  AppTemplate-Dev:/" \
    -e "s/^  ${NEW_NAME}-QA:\$/  AppTemplate-QA:/" \
    -e "s/^  ${NEW_NAME}-Prod:\$/  AppTemplate-Prod:/" \
    project.yml
fi

echo "Renaming folders and the app entry point..."
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  MV="git mv"
else
  MV="mv"
fi
run $MV AppTemplate "$NEW_NAME"
run $MV AppTemplateTests "${NEW_NAME}Tests"
if $DRY_RUN; then
  echo "  [dry-run] $MV $NEW_NAME/App/TemplateApp.swift $NEW_NAME/App/${NEW_NAME}App.swift"
else
  $MV "$NEW_NAME/App/TemplateApp.swift" "$NEW_NAME/App/${NEW_NAME}App.swift"
fi

if $DRY_RUN; then
  echo
  echo "Dry run complete — nothing changed. Re-run without --dry-run to apply."
  exit 0
fi

echo
echo "Regenerating Xcode project..."
xcodegen generate

echo
echo "Done. Remaining manual steps (README.md 'Making it your app', steps 2-5):"
echo "  - Replace the Item domain model with your real entity"
echo "  - Wire new dependencies into ${NEW_NAME}/App/AppDependencies.swift"
echo "  - Add real app icons to ${NEW_NAME}/Resources/Assets.xcassets/AppIcon.appiconset"
echo "  - Point BASE_URL in each ${NEW_NAME}/Config/*.xcconfig at your real API"
echo
echo "Verify the rename didn't break anything:"
echo "  swiftlint lint --strict"
echo "  xcodebuild build -project AppTemplate.xcodeproj -scheme AppTemplate-Dev -configuration Debug-DEV -destination 'generic/platform=iOS Simulator'"
echo
echo "Note: swiftlint's sorted_imports rule may now flag '@testable import ${NEW_NAME}' as"
echo "out of order in a test file or two — whether ${NEW_NAME} alphabetizes the same way"
echo "AppTemplate did depends on the name you picked. Swap the flagged import line with its"
echo "neighbor; it's a one-line fix SwiftLint's own error message points at directly."
