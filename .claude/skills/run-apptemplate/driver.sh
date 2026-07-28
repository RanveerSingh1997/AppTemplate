#!/usr/bin/env bash
# Driver for building, launching, and driving AppTemplate in the iOS Simulator via idb.
# Usage: driver.sh <command> [args...]
#   build                    xcodegen generate + xcodebuild for the simulator
#   boot                     boot the simulator, open Simulator.app, connect idb
#   install                  install the built .app
#   launch                   launch the app
#   terminate                terminate the app
#   uninstall                uninstall the app (clears mock data on next launch)
#   screenshot <path.png>    save a screenshot
#   tap <x> <y>              tap at point coordinates (NOT pixels — see `describe`)
#   text "<string>"          type into the currently focused field
#   key <keycode>            press a hardware key (e.g. 40 = Return)
#   describe                 dump accessibility tree with point-coordinate frames
#   wait                     poll until the app's first real screen has rendered
#   all                      build + boot + install + launch, then wait
set -euo pipefail

export PATH="$HOME/Library/Python/3.9/bin:$PATH"   # `idb` (fb-idb) installed via `pip3 install --user fb-idb`

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

export SIM_NAME="${SIM_NAME:-iPhone 17}"
SCHEME="AppTemplate-Dev"
CONFIG="Debug-DEV"
BUNDLE_ID="com.yourcompany.apptemplate.dev"
DERIVED_DATA="$REPO_ROOT/build"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG-iphonesimulator/AppTemplate.app"

udid() {
  xcrun simctl list devices -j | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
name = os.environ['SIM_NAME']
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == name and d['isAvailable']:
            print(d['udid']); sys.exit(0)
sys.exit('no available simulator named ' + name)
"
}

cmd_build() {
  xcodegen generate
  xcodebuild -project AppTemplate.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
    -destination "id=$(udid)" -derivedDataPath "$DERIVED_DATA" build
}

cmd_boot() {
  local id; id=$(udid)
  xcrun simctl boot "$id" 2>/dev/null || true   # already-booted exit code is nonzero; ignore
  xcrun simctl bootstatus "$id" -b
  open -a Simulator
  idb connect "$id" >/dev/null   # spawns idb_companion for this simulator if not already running
}

# NOTE: install/launch/terminate/uninstall go through `xcrun simctl`, not `idb` —
# this idb build (fb-idb 1.1.7) misreports this Mac's simulator target as x86_64 and
# rejects arm64-only iOS 17+ builds with "Targets architecture x86_64 not in the
# bundles supported architectures". `idb` is still used below for UI automation
# (tap/text/describe) and screenshots, which work fine.
cmd_install() { xcrun simctl install "$(udid)" "$APP_PATH"; }
cmd_launch()  { xcrun simctl launch "$(udid)" "$BUNDLE_ID"; }
cmd_terminate() { xcrun simctl terminate "$(udid)" "$BUNDLE_ID" || true; }
cmd_uninstall() { xcrun simctl uninstall "$(udid)" "$BUNDLE_ID" || true; }
cmd_screenshot() { idb screenshot --udid "$(udid)" "${1:?usage: screenshot <path.png>}"; }
cmd_tap() { idb ui tap --udid "$(udid)" "${1:?usage: tap <x> <y>}" "${2:?usage: tap <x> <y>}"; }
cmd_text() { idb ui text --udid "$(udid)" "${1:?usage: text <string>}"; }
cmd_key() { idb ui key --udid "$(udid)" "${1:?usage: key <keycode>}"; }
cmd_describe() { idb ui describe-all --udid "$(udid)"; }

# `simctl launch` returns as soon as the process spawns — well before SwiftUI has
# rendered past the splash screen (~0.6s sleep + init, but slower on a cold install).
# Fixed sleeps are unreliable (measured 2s as still-splash after a cold install); poll
# the accessibility tree instead and fail loudly if content never shows up.
cmd_wait() {
  local id; id=$(udid)
  local timeout="${WAIT_TIMEOUT:-15}"
  local start; start=$(date +%s)
  while true; do
    local count
    count=$(idb ui describe-all --udid "$id" 2>/dev/null | python3 -c "
import json, sys
try:
    print(len(json.load(sys.stdin)))
except Exception:
    print(0)
" 2>/dev/null || echo 0)
    [ "${count:-0}" -gt 3 ] && return 0
    if [ "$(( $(date +%s) - start ))" -ge "$timeout" ]; then
      echo "driver.sh wait: timed out after ${timeout}s waiting for app content to render" >&2
      return 1
    fi
    sleep 0.3
  done
}

cmd_all() { cmd_build; cmd_boot; cmd_install; cmd_launch; cmd_wait; }

case "${1:-}" in
  build) cmd_build ;;
  boot) cmd_boot ;;
  install) cmd_install ;;
  launch) cmd_launch ;;
  terminate) cmd_terminate ;;
  uninstall) cmd_uninstall ;;
  screenshot) shift; cmd_screenshot "$@" ;;
  tap) shift; cmd_tap "$@" ;;
  text) shift; cmd_text "$@" ;;
  key) shift; cmd_key "$@" ;;
  describe) cmd_describe ;;
  wait) cmd_wait ;;
  all) cmd_all ;;
  *)
    echo "usage: $0 {build|boot|install|launch|terminate|uninstall|screenshot <path>|tap <x> <y>|text <string>|key <code>|describe|wait|all}" >&2
    exit 1
    ;;
esac
