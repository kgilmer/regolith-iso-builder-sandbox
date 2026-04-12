#!/usr/bin/env bash
# capture-screenshots.sh — Boot the VM and capture deduplicated screenshots at 1fps.
#
# Usage:
#   ./capture-screenshots.sh <suite> <disk-image> [needles-dir]
#
# Arguments:
#   suite        Capture suite to run: wayland, x11 (required)
#   disk-image   Path to the Regolith Linux .img file (required)
#   needles-dir  Path to needle directory (optional, defaults to ./needles)
#
# Drives the full flow automatically: wizard → LightDM login → desktop → terminal.
# Use the captured PNGs from testresults/ as needle source images.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVMF_VARS_SRC="/usr/share/OVMF/OVMF_VARS_4M.fd"
OVMF_VARS="${SCRIPT_DIR}/ovmf_vars.fd"

# ── Argument handling ─────────────────────────────────────────────────────────

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <suite> <disk-image> [needles-dir]" >&2
    echo "  Suites: wayland, x11" >&2
    exit 1
fi

SUITE="$1"
VARS_TEMPLATE="${SCRIPT_DIR}/vars-capture-${SUITE}.json"

if [[ ! -f "${VARS_TEMPLATE}" ]]; then
    echo "ERROR: Unknown suite '${SUITE}' (no vars-capture-${SUITE}.json found)" >&2
    echo "  Available suites:" >&2
    for f in "${SCRIPT_DIR}"/vars-capture-*.json; do
        s="$(basename "$f" .json)"
        echo "    ${s#vars-capture-}" >&2
    done
    exit 1
fi

DISK_IMAGE="$(realpath "$2")"
NEEDLES_DIR="$(realpath "${3:-${SCRIPT_DIR}/needles}")"

if [[ ! -f "${DISK_IMAGE}" ]]; then
    echo "ERROR: Disk image not found: ${DISK_IMAGE}" >&2
    exit 1
fi

if [[ ! -d "${NEEDLES_DIR}" ]]; then
    echo "ERROR: Needles directory not found: ${NEEDLES_DIR}" >&2
    exit 1
fi

# ── Kill stale processes ─────────────────────────────────────────────────────

pkill -f "isotovideo" 2>/dev/null || true
pkill -f "qemu-system\|/usr/bin/kvm" 2>/dev/null || true
sleep 1

# ── Build vars.json from template ────────────────────────────────────────────

cp "${OVMF_VARS_SRC}" "${OVMF_VARS}"

sed -e "s|@CASEDIR@|${SCRIPT_DIR}|g" \
    -e "s|@NEEDLES_DIR@|${NEEDLES_DIR}|g" \
    -e "s|@HDD_1@|${DISK_IMAGE}|g" \
    -e "s|@UEFI_PFLASH_VARS@|${OVMF_VARS}|g" \
    "${VARS_TEMPLATE}" > "${SCRIPT_DIR}/vars.json"

echo "==> Starting capture run..."
echo "    Suite:       ${SUITE}"
echo "    Disk image:  ${DISK_IMAGE}"
echo "    Needles dir: ${NEEDLES_DIR}"
echo "    Screenshots: ${SCRIPT_DIR}/testresults/"
cd "${SCRIPT_DIR}"
exec isotovideo
