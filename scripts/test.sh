#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if command -v fvm >/dev/null 2>&1 && [[ -f .fvmrc ]]; then
  flutter_command=(fvm flutter)
else
  flutter_command=(flutter)
fi

usage() {
  cat <<'EOF'
Usage: ./scripts/test.sh [command] [device-id]

Commands:
  check                 Fetch packages, analyze, and run unit/widget tests.
  unit                  Run unit and widget tests only.
  integration [device]  Run integration tests on a connected device/emulator.
  integration-binary [device] [apk]
                        Run integration tests using a pre-built test APK.
  all [device]          Run check, then integration tests.
  build                 Build the Android debug APK.
  build-integration     Build the Android integration-test APK.

DEVICE_ID may be used instead of the device-id argument.
The default command is "check".
EOF
}

run_unit_tests() {
  "${flutter_command[@]}" test test
}

run_check() {
  "${flutter_command[@]}" pub get
  "${flutter_command[@]}" analyze
  run_unit_tests
}

run_integration_tests() {
  local device_id="${1:-${DEVICE_ID:-}}"
  if [[ -z "$device_id" ]]; then
    echo "An Android device or emulator id is required." >&2
    echo "Available devices:" >&2
    "${flutter_command[@]}" devices
    echo "Retry with: ./scripts/test.sh integration <device-id>" >&2
    exit 2
  fi
  "${flutter_command[@]}" test integration_test -d "$device_id"
}

run_integration_binary() {
  local device_id="${1:-${DEVICE_ID:-}}"
  local apk_path="${2:-${APK_PATH:-}}"
  if [[ -z "$device_id" || -z "$apk_path" ]]; then
    echo "An Android device id and integration APK path are required." >&2
    echo "Retry with: ./scripts/test.sh integration-binary <device-id> <apk>" >&2
    exit 2
  fi
  if [[ ! -f "$apk_path" ]]; then
    echo "Integration APK not found: $apk_path" >&2
    exit 2
  fi
  "${flutter_command[@]}" drive \
    --driver integration_test/driver.dart \
    --target integration_test/app_flow_test.dart \
    --device-id "$device_id" \
    --use-application-binary "$apk_path"
}

command_name="${1:-check}"
case "$command_name" in
  check)
    run_check
    ;;
  unit)
    run_unit_tests
    ;;
  integration)
    run_integration_tests "${2:-}"
    ;;
  integration-binary)
    run_integration_binary "${2:-}" "${3:-}"
    ;;
  all)
    run_check
    run_integration_tests "${2:-}"
    ;;
  build)
    "${flutter_command[@]}" build apk --debug
    ;;
  build-integration)
    "${flutter_command[@]}" build apk \
      --debug \
      --target integration_test/app_flow_test.dart
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage >&2
    exit 2
    ;;
esac
