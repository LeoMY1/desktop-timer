#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
configuration="${1:-release}"
if [ "$configuration" != "test" ] && [ "$configuration" != "release" ]; then
  printf 'Usage: bash scripts/build.sh test|release\n' >&2
  exit 2
fi
build_root="$project_root/work/build/$configuration"
bundle="$project_root/outputs/StudyTimer.app"
flags=(-D PRODUCTION)
if [ "$configuration" = "test" ]; then
  flags=(-D INTERNAL_TESTING)
  bundle="$project_root/work/build/test/StudyTimer-Checks.app"
fi
mkdir -p "$build_root" "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
sdk_path="$(xcrun --show-sdk-path)"
optimization="-O"

xcrun swiftc "${flags[@]}" -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -parse-as-library -emit-module -module-name WindowGeometry -emit-module-path "$build_root/WindowGeometry.swiftmodule" "$project_root/Sources/WindowGeometry/PanelLayout.swift"
xcrun swiftc "${flags[@]}" -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -parse-as-library -emit-object -module-name WindowGeometry "$project_root/Sources/WindowGeometry/PanelLayout.swift" -o "$build_root/WindowGeometry.o"
xcrun swiftc "${flags[@]}" -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -parse-as-library -emit-module -module-name StudyCore "$project_root"/Sources/StudyCore/*.swift -emit-module-path "$build_root/StudyCore.swiftmodule"
xcrun swiftc "${flags[@]}" -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -parse-as-library -whole-module-optimization -emit-object -module-name StudyCore "$project_root"/Sources/StudyCore/*.swift -o "$build_root/StudyCore.o"
xcrun swiftc "${flags[@]}" -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -I "$build_root" "$project_root"/Sources/StudyTimerApp/*.swift "$build_root/WindowGeometry.o" "$build_root/StudyCore.o" -o "$build_root/StudyTimer"
cp "$build_root/StudyTimer" "$bundle/Contents/MacOS/StudyTimer"
cp "$project_root/resources/Info.plist" "$bundle/Contents/Info.plist"
if [ "$configuration" = "test" ]; then
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.study-timer.internal-checks' "$bundle/Contents/Info.plist"
fi
xcrun swift -target arm64-apple-macosx13.0 "$project_root/scripts/make-icon.swift" "$build_root/icon"
iconutil -c icns "$build_root/icon/AppIcon.iconset" -o "$bundle/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$bundle"
codesign --verify --strict --verbose=2 "$bundle"
printf '%s\n' "$bundle"
