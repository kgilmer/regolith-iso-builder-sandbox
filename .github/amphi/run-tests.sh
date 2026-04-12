#!/usr/bin/env bash
# run-tests.sh — Run the full os-autoinst test suite against a Regolith image.
#
# Usage:
#   ./run-tests.sh <suite> <disk-image> [needles-dir]
#
# Arguments:
#   suite        Test suite to run: wayland, x11 (required)
#   disk-image   Path to the Regolith Linux .img file to test (required)
#   needles-dir  Path to needle directory (optional, defaults to ./needles)
#
# os-autoinst creates its own qcow2 overlay of HDD_1 in raid/ so the baseline
# image is never modified.  A fresh OVMF vars copy is made each run so UEFI
# boot state is clean.

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
VARS_TEMPLATE="${SCRIPT_DIR}/vars-test-${SUITE}.json"

if [[ ! -f "${VARS_TEMPLATE}" ]]; then
    echo "ERROR: Unknown suite '${SUITE}' (no vars-test-${SUITE}.json found)" >&2
    echo "  Available suites:" >&2
    for f in "${SCRIPT_DIR}"/vars-test-*.json; do
        s="$(basename "$f" .json)"
        echo "    ${s#vars-test-}" >&2
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

# ── Dependency checks ────────────────────────────────────────────────────────

if ! command -v isotovideo &>/dev/null; then
    echo "ERROR: isotovideo not found. Run: sudo apt-get install os-autoinst" >&2
    exit 1
fi

if [[ ! -f "${OVMF_VARS_SRC}" ]]; then
    echo "ERROR: OVMF vars not found at ${OVMF_VARS_SRC}. Run: sudo apt-get install ovmf" >&2
    exit 1
fi

# ── Build vars.json from template ────────────────────────────────────────────

cp "${OVMF_VARS_SRC}" "${OVMF_VARS}"

sed -e "s|@CASEDIR@|${SCRIPT_DIR}|g" \
    -e "s|@NEEDLES_DIR@|${NEEDLES_DIR}|g" \
    -e "s|@HDD_1@|${DISK_IMAGE}|g" \
    -e "s|@UEFI_PFLASH_VARS@|${OVMF_VARS}|g" \
    "${VARS_TEMPLATE}" > "${SCRIPT_DIR}/vars.json"

echo "==> Starting isotovideo..."
echo "    Suite:       ${SUITE}"
echo "    Disk image:  ${DISK_IMAGE}"
echo "    Needles dir: ${NEEDLES_DIR}"
echo "    Results:     ${SCRIPT_DIR}/testresults/"
cd "${SCRIPT_DIR}"
isotovideo || true

# isotovideo exits 0 even when tests fail — it reports outcome via result JSONs.
# Scan them and exit non-zero if any test did not pass so CI fails correctly.
shopt -s nullglob
failed=()
results=("${SCRIPT_DIR}"/testresults/result-*.json)
if [[ ${#results[@]} -eq 0 ]]; then
    echo "ERROR: no test result files found in testresults/" >&2
    exit 1
fi
for r in "${results[@]}"; do
    if grep -qE '"result"[[:space:]]*:[[:space:]]*"(fail|softfail)"' "$r"; then
        failed+=("$(basename "$r")")
    fi
done
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "==> Test failures: ${failed[*]}" >&2
    exit 1
fi
echo "==> All tests passed."
