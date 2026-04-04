#!/usr/bin/env bash
set -euo pipefail

# Deterministic App Store mobile screenshot capture for SaneClip.
# Captures dark-mode iPhone + iPad screenshots for history/pinned/settings.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/docs/images"
DERIVED_DATA="${ROOT_DIR}/build/ScreenshotDerivedData"

IPHONE_NAME="${IPHONE_NAME:-iPhone 17 Pro Max}"
IPAD_NAME="${IPAD_NAME:-iPad Pro 13-inch (M5)}"

log() {
  printf '[capture] %s\n' "$1"
}

run_with_timeout() {
  local seconds="$1"
  shift
  python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

timeout = int(sys.argv[1])
cmd = sys.argv[2:]

try:
    completed = subprocess.run(cmd, timeout=timeout)
    raise SystemExit(completed.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
}

device_udid() {
  local preferred="$1"
  local fallback_pattern="$2"
  local udid
  udid="$(xcrun simctl list devices available --json | jq -r --arg NAME "${preferred}" '.devices[][] | select(.name == $NAME) | .udid' | head -n1)"
  if [[ -z "${udid}" ]]; then
    udid="$(xcrun simctl list devices available --json | jq -r --arg PATTERN "${fallback_pattern}" '.devices[][] | select(.name | test($PATTERN; "i")) | .udid' | head -n1)"
  fi
  printf '%s' "${udid}"
}

boot_and_style() {
  local udid="$1"
  xcrun simctl boot "${udid}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${udid}" -b >/dev/null
  xcrun simctl ui "${udid}" appearance dark >/dev/null 2>&1 || true
  xcrun simctl status_bar "${udid}" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

install_app() {
  local udid="$1"
  local app_path="$2"
  if xcrun simctl install "${udid}" "${app_path}" >/dev/null 2>&1; then
    return 0
  fi

  log "Install retried after re-booting simulator ${udid}"
  boot_and_style "${udid}"
  xcrun simctl install "${udid}" "${app_path}" >/dev/null
}

capture_tab() {
  local udid="$1"
  local bundle_id="$2"
  local tab="$3"
  local output="$4"
  local launch_log="/tmp/saneclip_capture_${tab}_$(basename "${output}").log"

  xcrun simctl terminate "${udid}" "${bundle_id}" >/dev/null 2>&1 || true
  log "Launching ${tab} on ${udid}"
  if ! run_with_timeout 20 xcrun simctl launch "${udid}" "${bundle_id}" -- --skip-onboarding --screenshot-tab "${tab}" >"${launch_log}" 2>&1; then
    status=$?
    if [[ "${status}" -eq 124 ]]; then
      log "Launch timed out for ${tab}; continuing because the app may already be visible"
    else
    echo "Launch failed for ${bundle_id} (${tab}). See ${launch_log}" >&2
    sed -n '1,120p' "${launch_log}" >&2 || true
    exit 1
    fi
  fi
  sleep 2
  xcrun simctl io "${udid}" screenshot "${output}" >/dev/null
  log "Saved ${output}"
}

mkdir -p "${OUT_DIR}"

log "Building SaneClipIOS for simulator..."
xcodebuild \
  -project "${ROOT_DIR}/SaneClip.xcodeproj" \
  -scheme SaneClipIOS \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "${DERIVED_DATA}" \
  build >/tmp/saneclip_capture_build.log 2>&1

IOS_APP="$(find "${DERIVED_DATA}/Build/Products/Debug-iphonesimulator" -maxdepth 1 -type d -name '*.app' | grep -v '\.appex' | head -n1)"
if [[ ! -d "${IOS_APP}" ]]; then
  echo "Could not find built iOS app under ${DERIVED_DATA}/Build/Products/Debug-iphonesimulator" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${IOS_APP}/Info.plist")"

IPHONE_UDID="$(device_udid "${IPHONE_NAME}" "iphone")"
IPAD_UDID="$(device_udid "${IPAD_NAME}" "ipad pro")"

if [[ -z "${IPHONE_UDID}" || -z "${IPAD_UDID}" ]]; then
  echo "Could not resolve simulator UDIDs (iphone: ${IPHONE_NAME}, ipad: ${IPAD_NAME})." >&2
  exit 1
fi

log "Using iPhone UDID: ${IPHONE_UDID}"
log "Using iPad UDID: ${IPAD_UDID}"
log "Using bundle ID: ${BUNDLE_ID}"

boot_and_style "${IPHONE_UDID}"
boot_and_style "${IPAD_UDID}"

log "Installing app on simulators..."
install_app "${IPHONE_UDID}" "${IOS_APP}"
install_app "${IPAD_UDID}" "${IOS_APP}"

capture_tab "${IPHONE_UDID}" "${BUNDLE_ID}" history "${OUT_DIR}/screenshot-ios-history-dark.png"
capture_tab "${IPHONE_UDID}" "${BUNDLE_ID}" pinned "${OUT_DIR}/screenshot-ios-pinned-dark.png"
capture_tab "${IPHONE_UDID}" "${BUNDLE_ID}" settings "${OUT_DIR}/screenshot-ios-settings-dark.png"

capture_tab "${IPAD_UDID}" "${BUNDLE_ID}" history "${OUT_DIR}/screenshot-ipad-history-dark.png"
capture_tab "${IPAD_UDID}" "${BUNDLE_ID}" pinned "${OUT_DIR}/screenshot-ipad-pinned-dark.png"
capture_tab "${IPAD_UDID}" "${BUNDLE_ID}" settings "${OUT_DIR}/screenshot-ipad-settings-dark.png"

log "Final dimensions:"
for f in "${OUT_DIR}"/screenshot-ios-*-dark.png "${OUT_DIR}"/screenshot-ipad-*-dark.png; do
  w="$(sips -g pixelWidth "${f}" 2>/dev/null | awk '/pixelWidth/{print $2}')"
  h="$(sips -g pixelHeight "${f}" 2>/dev/null | awk '/pixelHeight/{print $2}')"
  printf '  %s %sx%s\n' "$(basename "${f}")" "${w}" "${h}"
done | sort

log "Done."
