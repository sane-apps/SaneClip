#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/docs/images}"
RENDER_OUTPUT_DIR="${RENDER_OUTPUT_DIR:-$HOME/Library/Containers/com.saneclip.app/Data/tmp/AppStoreScreenshots}"
SCHEME="${SCHEME:-SaneClip}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/SaneClipMacAppStoreShots}"
OUTPUT_HINT_FILE="${OUTPUT_HINT_FILE:-/tmp/saneclip_screenshot_dir.txt}"
MINI_HOST="${MINI_HOST:-mini}"
ALLOW_LOCAL_CAPTURE="${ALLOW_LOCAL_CAPTURE:-0}"

log() {
  printf '[screenshots] %s\n' "$1" >&2
}

enforce_mini_first() {
  local host_short host_lc user_lc
  host_short="$(hostname -s 2>/dev/null || hostname)"
  host_lc="$(printf '%s' "${host_short}" | tr '[:upper:]' '[:lower:]')"
  user_lc="$(printf '%s' "${USER:-}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${host_lc}" == *mini* ]] || [[ "${user_lc}" == "stephansmac" ]]; then
    return 0
  fi

  if [[ "${ALLOW_LOCAL_CAPTURE}" == "1" ]]; then
    log "ALLOW_LOCAL_CAPTURE=1 set; bypassing mini-first enforcement."
    return 0
  fi

  if command -v ssh >/dev/null 2>&1 && ssh -o BatchMode=yes -o ConnectTimeout=2 "${MINI_HOST}" true >/dev/null 2>&1; then
    echo "Refusing local screenshot capture while Mini is reachable." >&2
    echo "Run this on Mini instead:" >&2
    echo "  ssh ${MINI_HOST} 'cd ${PROJECT_ROOT} && bash scripts/capture_appstore_macos_screenshots.sh'" >&2
    exit 2
  fi

  log "Mini unreachable; continuing locally."
}

mkdir -p "${OUTPUT_DIR}" "${RENDER_OUTPUT_DIR}"
enforce_mini_first

rm -rf "${DERIVED_DATA_PATH}"
rm -f "${OUTPUT_HINT_FILE}"
find "${RENDER_OUTPUT_DIR}" -maxdepth 1 -name 'appstore-macos-*.png' -delete 2>/dev/null || true
find "${OUTPUT_DIR}" -maxdepth 1 -name 'appstore-macos-*.png' -delete 2>/dev/null || true
printf '%s\n' "${RENDER_OUTPUT_DIR}" > "${OUTPUT_HINT_FILE}"

trap 'rm -f "${OUTPUT_HINT_FILE}"' EXIT

log "Rendering SaneClip macOS App Store screenshots"
(
  cd "${PROJECT_ROOT}"
  xcodebuild \
    -project SaneClip.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "platform=macOS" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    test >/tmp/saneclip_macos_screenshot_capture.log
)

for screenshot in \
  appstore-macos-history.png \
  appstore-macos-general.png \
  appstore-macos-shortcuts.png \
  appstore-macos-snippets.png \
  appstore-macos-license.png
do
  if [[ ! -f "${RENDER_OUTPUT_DIR}/${screenshot}" ]]; then
    echo "Missing rendered screenshot: ${RENDER_OUTPUT_DIR}/${screenshot}" >&2
    exit 1
  fi
  cp "${RENDER_OUTPUT_DIR}/${screenshot}" "${OUTPUT_DIR}/${screenshot}"
done

log "Wrote screenshots to ${OUTPUT_DIR}"
