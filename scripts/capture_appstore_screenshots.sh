#!/usr/bin/env bash
set -euo pipefail

# Deterministic App Store mobile screenshot capture for SaneClip.
# Captures dark-mode iPhone + iPad screenshots for history/pinned/settings.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/docs/images"
DERIVED_DATA="${ROOT_DIR}/build/ScreenshotDerivedData"

IPHONE_NAME="${IPHONE_NAME:-iPhone 17 Pro Max}"
IPAD_NAME="${IPAD_NAME:-iPad Pro 13-inch (M5)}"
CONFIGURATION="${CONFIGURATION:-Debug}"
# iphone, ipad, or both. Default stays both for the existing full capture.
CAPTURE_DEVICES="${CAPTURE_DEVICES:-both}"
# Comma list. Default captures every proof and store shot.
CAPTURE_SHOTS="${CAPTURE_SHOTS:-history,pinned,settings,onboarding,empty}"
PROOF_DIR="${ROOT_DIR}/outputs/ios-runtime-proof"
BOOTED_UDIDS=()

shutdown_booted() {
  local udid
  for udid in "${BOOTED_UDIDS[@]:-}"; do
    xcrun simctl shutdown "${udid}" >/dev/null 2>&1 || true
  done
}
trap shutdown_booted EXIT

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
  local status=0

  xcrun simctl terminate "${udid}" "${bundle_id}" >/dev/null 2>&1 || true
  log "Launching ${tab} on ${udid}"
  run_with_timeout 20 xcrun simctl launch "${udid}" "${bundle_id}" -- --skip-onboarding --screenshot-tab "${tab}" >"${launch_log}" 2>&1 || status=$?
  if [[ "${status}" -ne 0 ]]; then
    if [[ "${status}" -eq 124 ]]; then
      log "Launch timed out for ${tab}; continuing because the app may already be visible"
    else
      log "Launch failed for ${tab} with status ${status}; re-booting simulator and retrying once"
      boot_and_style "${udid}"
      status=0
      run_with_timeout 20 xcrun simctl launch "${udid}" "${bundle_id}" -- --skip-onboarding --screenshot-tab "${tab}" >"${launch_log}" 2>&1 || status=$?
      if [[ "${status}" -ne 0 ]]; then
        echo "Launch failed for ${bundle_id} (${tab}). See ${launch_log}" >&2
        sed -n '1,120p' "${launch_log}" >&2 || true
        exit 1
      fi
    fi
  fi
  capture_frame "${udid}" "${output}"
  log "Saved ${output}"
}

# The open animation is a small rounded card on the wallpaper.
# A size check accepts that card. Wait until the bottom controls are bright.
frame_is_settled() {
  python3 - "$1" << 'PY'
import subprocess, struct, sys, os
src = sys.argv[1]
bmp = src + ".bmp"
subprocess.check_call(["sips", "-s", "format", "bmp", src, "--out", bmp], stdout=subprocess.DEVNULL)
data = open(bmp, "rb").read()
os.remove(bmp)
off = struct.unpack_from("<I", data, 10)[0]
w = abs(struct.unpack_from("<i", data, 18)[0])
raw_h = struct.unpack_from("<i", data, 22)[0]
top_down = raw_h < 0
h = abs(raw_h)
bpp = struct.unpack_from("<H", data, 28)[0]
stride = ((w * (bpp // 8) + 3) // 4) * 4

def pix(x, y):
    src_y = y if top_down else (h - 1 - y)
    i = off + src_y * stride + x * (bpp // 8)
    b, g, r = data[i], data[i + 1], data[i + 2]
    return r + g + b

body = 0
for y in range(int(h * 0.08), int(h * 0.62), 6):
    for x in range(0, w, 8):
        if pix(x, y) > 180:
            body += 1
bottom = 0
for y in range(int(h * 0.84), int(h * 0.97), 4):
    for x in range(int(w * 0.12), int(w * 0.88), 6):
        if pix(x, y) > 400:
            bottom += 1
# iPad keeps History, Pinned, and Settings in a tab bar under the status bar.
top = 0
if w >= 1800:
    for y in range(int(h * 0.03), int(h * 0.18), 4):
        for x in range(int(w * 0.15), int(w * 0.85), 8):
            if pix(x, y) > 400:
                top += 1
def channel_max(x, y):
    src_y = y if top_down else (h - 1 - y)
    i = off + src_y * stride + x * (bpp // 8)
    return max(data[i], data[i + 1], data[i + 2])
corners = [channel_max(2, 2), channel_max(w - 3, 2), channel_max(2, h - 3), channel_max(w - 3, h - 3)]
# A mid-open frame is a rounded card on a tinted wallpaper.
full_bleed = max(corners) < 40
print(f"body={body} bottom={bottom} top={top} corners={max(corners)}")
settled = body > 40 and full_bleed and (bottom > 6 or top > 12)
sys.exit(0 if settled else 1)
PY
}

capture_frame() {
  local udid="$1"
  local output="$2"
  local attempt ready=0
  local tmp="/tmp/saneclip-frame-$$.png"
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
    xcrun simctl io "${udid}" screenshot "${tmp}" >/dev/null
    if frame_is_settled "${tmp}"; then
      ready=$((ready + 1))
      if [[ "${ready}" -ge 2 ]]; then
        cp "${tmp}" "${output}"
        rm -f "${tmp}"
        return 0
      fi
    else
      ready=0
    fi
    sleep 1
  done
  cp "${tmp}" "${output}" 2>/dev/null || true
  rm -f "${tmp}"
  echo "Screenshot never settled: ${output}" >&2
  return 1
}

mkdir -p "${OUT_DIR}"

mkdir -p "${PROOF_DIR}"
BUILD_LOG="${PROOF_DIR}/capture-build-${CONFIGURATION}.log"
SIGNING_OVERRIDES=()
if [[ "${CONFIGURATION}" == "Release-AppStore" ]]; then
  # The App Store profile cannot sign a simulator slice.
  SIGNING_OVERRIDES=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= PROVISIONING_PROFILE=)
fi

if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  log "Skipping build; using the existing simulator app"
else
  log "Building SaneClipIOS (${CONFIGURATION}) for simulator..."
  xcodebuild \
    -project "${ROOT_DIR}/SaneClip.xcodeproj" \
    -scheme SaneClipIOS \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "${DERIVED_DATA}" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    "${SIGNING_OVERRIDES[@]}" \
    build >"${BUILD_LOG}" 2>&1
fi

IOS_APP="$(find "${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator" -maxdepth 1 -type d -name '*.app' | grep -v '\.appex' | head -n1)"
if [[ ! -d "${IOS_APP}" ]]; then
  echo "Could not find built iOS app under ${DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${IOS_APP}/Info.plist")"

want_iphone=0
want_ipad=0
case "${CAPTURE_DEVICES}" in
  iphone) want_iphone=1 ;;
  ipad) want_ipad=1 ;;
  both) want_iphone=1; want_ipad=1 ;;
  *) echo "CAPTURE_DEVICES must be iphone, ipad, or both" >&2; exit 1 ;;
esac

IPHONE_UDID=""
IPAD_UDID=""
if [[ "${want_iphone}" == "1" ]]; then
  IPHONE_UDID="$(device_udid "${IPHONE_NAME}" "iphone")"
  [[ -n "${IPHONE_UDID}" ]] || { echo "Could not resolve iPhone simulator ${IPHONE_NAME}" >&2; exit 1; }
fi
if [[ "${want_ipad}" == "1" ]]; then
  IPAD_UDID="$(device_udid "${IPAD_NAME}" "ipad pro")"
  [[ -n "${IPAD_UDID}" ]] || { echo "Could not resolve iPad simulator ${IPAD_NAME}" >&2; exit 1; }
fi

log "Using bundle ID: ${BUNDLE_ID}"

capture_device() {
  local udid="$1"
  local prefix="$2"
  local proof_name="$3"
  BOOTED_UDIDS+=("${udid}")
  boot_and_style "${udid}"
  install_app "${udid}" "${IOS_APP}"
  local stream_log="${PROOF_DIR}/${proof_name}-log.txt"
  xcrun simctl spawn "${udid}" log stream --style compact --level info --predicate 'process == "SaneClip"' >"${stream_log}" 2>&1 &
  local stream_pid=$!
  if [[ ",${CAPTURE_SHOTS}," == *",onboarding,"* ]]; then
    xcrun simctl terminate "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
    xcrun simctl launch "${udid}" "${BUNDLE_ID}" -- --force-onboarding >"${PROOF_DIR}/${proof_name}-onboarding-launch.txt" 2>&1 || true
    capture_frame "${udid}" "${PROOF_DIR}/${proof_name}-onboarding.png"
  fi
  if [[ ",${CAPTURE_SHOTS}," == *",history,"* ]]; then
    capture_tab "${udid}" "${BUNDLE_ID}" history "${OUT_DIR}/screenshot-${prefix}-history-dark.png"
  fi
  if [[ ",${CAPTURE_SHOTS}," == *",pinned,"* ]]; then
    capture_tab "${udid}" "${BUNDLE_ID}" pinned "${OUT_DIR}/screenshot-${prefix}-pinned-dark.png"
  fi
  if [[ ",${CAPTURE_SHOTS}," == *",settings,"* ]]; then
    capture_tab "${udid}" "${BUNDLE_ID}" settings "${OUT_DIR}/screenshot-${prefix}-settings-dark.png"
  fi
  # A normal launch must stay empty. This shot is proof, not a store image.
  if [[ ",${CAPTURE_SHOTS}," == *",empty,"* ]]; then
    xcrun simctl terminate "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
    xcrun simctl launch "${udid}" "${BUNDLE_ID}" -- --skip-onboarding >"${PROOF_DIR}/${proof_name}-empty-launch.txt" 2>&1 || true
    capture_frame "${udid}" "${PROOF_DIR}/${proof_name}-empty.png"
  fi
  kill "${stream_pid}" >/dev/null 2>&1 || true
  xcrun simctl shutdown "${udid}" >/dev/null 2>&1 || true
}

if [[ "${want_iphone}" == "1" ]]; then
  log "Using iPhone UDID: ${IPHONE_UDID}"
  capture_device "${IPHONE_UDID}" "ios" "iphone"
fi
if [[ "${want_ipad}" == "1" ]]; then
  log "Using iPad UDID: ${IPAD_UDID}"
  capture_device "${IPAD_UDID}" "ipad" "ipad"
fi

log "Final dimensions:"
for f in "${OUT_DIR}"/screenshot-ios-*-dark.png "${OUT_DIR}"/screenshot-ipad-*-dark.png; do
  w="$(sips -g pixelWidth "${f}" 2>/dev/null | awk '/pixelWidth/{print $2}')"
  h="$(sips -g pixelHeight "${f}" 2>/dev/null | awk '/pixelHeight/{print $2}')"
  printf '  %s %sx%s\n' "$(basename "${f}")" "${w}" "${h}"
done | sort

log "Done."
