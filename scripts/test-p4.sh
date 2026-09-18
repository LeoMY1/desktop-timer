#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
build_root="$project_root/work/p4-build/tests"
mkdir -p "$build_root"
sdk_path="$(xcrun --show-sdk-path)"
args=(-target arm64-apple-macosx13.0 -sdk "$sdk_path" -module-cache-path "$project_root/work/module-cache" -I "$project_root/Sources/CSQLite")
xcrun swiftc "${args[@]}" -parse-as-library -emit-module -module-name StudyCore Sources/StudyCore/*.swift -emit-module-path "$build_root/StudyCore.swiftmodule"
xcrun swiftc "${args[@]}" -parse-as-library -whole-module-optimization -emit-object -module-name StudyCore Sources/StudyCore/*.swift -o "$build_root/StudyCore.o"
xcrun swiftc "${args[@]}" -I "$build_root" Tests/StudyRecordChecks/main.swift "$build_root/StudyCore.o" -o "$build_root/CoreChecks"
"$build_root/CoreChecks" "$project_root/work/p4-v2-evidence/core"
