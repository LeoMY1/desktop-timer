#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
test_root="$project_root/work/geometry-checks"
sdk_path="$(xcrun --show-sdk-path)"
mkdir -p "$test_root" "$project_root/work/p2-evidence"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" -parse-as-library -emit-module -module-name WindowGeometry -emit-module-path "$test_root/WindowGeometry.swiftmodule" "$project_root/Sources/WindowGeometry/PanelLayout.swift"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" -parse-as-library -emit-object -module-name WindowGeometry "$project_root/Sources/WindowGeometry/PanelLayout.swift" -o "$test_root/WindowGeometry.o"
xcrun swiftc -target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" -I "$test_root" "$project_root/Tests/WindowGeometryChecks/main.swift" "$test_root/WindowGeometry.o" -o "$test_root/GeometryChecks"
"$test_root/GeometryChecks" "$project_root/work/p2-evidence/geometry-checks.json"

