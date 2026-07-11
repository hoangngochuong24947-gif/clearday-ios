#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Validating Xcode project..."
plutil -lint ClearDay.xcodeproj/project.pbxproj >/dev/null
xcodebuild -project ClearDay.xcodeproj -scheme ClearDay -list >/dev/null

echo "Type-checking app sources..."
mapfile_command="mapfile"
if ! command -v "$mapfile_command" >/dev/null 2>&1; then
  app_swift_files=($(find ClearDay -name '*.swift' -print))
else
  mapfile -t app_swift_files < <(find ClearDay -name '*.swift' -print)
fi
xcrun --sdk iphoneos swiftc \
  -typecheck \
  -target arm64-apple-ios17.0 \
  -module-name ClearDay \
  "${app_swift_files[@]}"

echo "Parsing test sources..."
if ! command -v "$mapfile_command" >/dev/null 2>&1; then
  test_swift_files=($(find ClearDayTests ClearDayUITests -name '*.swift' -print))
else
  mapfile -t test_swift_files < <(find ClearDayTests ClearDayUITests -name '*.swift' -print)
fi
xcrun swiftc -frontend -parse "${test_swift_files[@]}"

if xcrun simctl list runtimes 2>/dev/null | grep -E '^iOS ' | grep -Fqv '(unavailable)'; then
  echo "Building for iOS Simulator..."
  xcodebuild \
    -project ClearDay.xcodeproj \
    -scheme ClearDay \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  echo "No available iOS Simulator runtime; compile build deferred."
fi

echo "Verification complete."
