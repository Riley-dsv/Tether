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
  all [device]          Run check, then integration tests.
  build                 Build the Android debug APK.

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
  all)
    run_check
    run_integration_tests "${2:-}"
    ;;
  build)
    "${flutter_command[@]}" build apk --debug
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
