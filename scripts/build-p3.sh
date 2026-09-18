#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
configuration="${1:-release}"
if [ "$configuration" != "debug" ] && [ "$configuration" != "release" ]; then
  printf 'Usage: bash scripts/build.sh debug|release\n' >&2
  exit 2
fi
build_root="$project_root/work/p3-build/$configuration"
bundle="$project_root/outputs/P3-v1/StudyTimer.app"
mkdir -p "$build_root" "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
sdk_path="$(xcrun --show-sdk-path)"
optimization="-O"
if [ "$configuration" = "debug" ]; then optimization="-Onone"; fi
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -parse-as-library -emit-module -module-name WindowGeometry -emit-module-path "$build_root/WindowGeometry.swiftmodule" "$project_root/Sources/WindowGeometry/PanelLayout.swift"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -parse-as-library -emit-object -module-name WindowGeometry "$project_root/Sources/WindowGeometry/PanelLayout.swift" -o "$build_root/WindowGeometry.o"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -parse-as-library -emit-module -module-name StudyCore "$project_root"/Sources/StudyCore/*.swift -emit-module-path "$build_root/StudyCore.swiftmodule"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -parse-as-library -whole-module-optimization -emit-object -module-name StudyCore "$project_root"/Sources/StudyCore/*.swift -o "$build_root/StudyCore.o"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" "$optimization" -I "$project_root/Sources/CSQLite" -I "$build_root" "$project_root"/Sources/StudyTimerApp/*.swift "$build_root/WindowGeometry.o" "$build_root/StudyCore.o" -o "$build_root/StudyTimer"
cp "$build_root/StudyTimer" "$bundle/Contents/MacOS/StudyTimer"
cp "$project_root/resources/Info-P3.plist" "$bundle/Contents/Info.plist"
xcrun swift -target arm64-apple-macosx13.0 "$project_root/scripts/make-icon.swift" "$project_root/work/icon"
iconutil -c icns "$project_root/work/icon/AppIcon.iconset" -o "$bundle/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$bundle"
codesign --verify --strict --verbose=2 "$bundle"
printf '%s\n' "$bundle"
