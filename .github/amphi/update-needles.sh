#!/usr/bin/env bash
# update-needles.sh — Auto-generate needle PNGs (and default JSONs) from a capture run.
#
# Usage:
#   ./capture-screenshots.sh /path/to/image.img
#   ./update-needles.sh [--force-json]
#
# Parses the isotovideo log from the most recent capture run to find NEEDLE:
# markers emitted by capture_screenshots.pm. Each marker is paired with the
# most recent SNAP: line (the last unique frame before the UI interaction).
#
# Options:
#   --force-json   Overwrite existing needle JSON files (default: preserve hand-tuned JSONs)
#
# What it does:
#   1. Copies the correct frame PNG to needles/<tag>.png (always overwrites)
#   2. Generates a default needle JSON if one doesn't already exist
#      (or if --force-json is set)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEEDLES_DIR="${SCRIPT_DIR}/needles"
RESULTS_DIR="${SCRIPT_DIR}/testresults"

FORCE_JSON=false
if [[ "${1:-}" == "--force-json" ]]; then
    FORCE_JSON=true
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

# Get PNG dimensions via identify (ImageMagick) or python3 as fallback
get_image_size() {
    local png="$1"
    if command -v identify &>/dev/null; then
        identify -format '%w %h' "${png}" 2>/dev/null && return
    fi
    python3 -c "
import struct, zlib
with open('${png}', 'rb') as f:
    f.read(16)
    w, h = struct.unpack('>II', f.read(8))
    print(w, h)
" 2>/dev/null || echo "1024 768"
}

# Generate a default needle JSON with a center match region and status bar exclude
generate_default_json() {
    local tag="$1"
    local png="$2"
    local json="$3"

    read -r width height <<< "$(get_image_size "${png}")"

    # Default: match the central area (leaving margins), exclude bottom status bar
    local margin_x=$(( width / 8 ))
    local margin_y=$(( height / 8 ))
    local match_w=$(( width - 2 * margin_x ))
    local match_h=$(( height - 2 * margin_y ))

    # Status bar exclude: bottom 28px, full width
    local bar_y=$(( height - 28 ))

    cat > "${json}" << EOF
{
  "area": [
    {"type": "match", "xpos": ${margin_x}, "ypos": ${margin_y}, "width": ${match_w}, "height": ${match_h}, "match": 85},
    {"type": "exclude", "xpos": 0, "ypos": ${bar_y}, "width": ${width}, "height": 28}
  ],
  "tags": ["${tag}"],
  "properties": []
}
EOF
}

# ── Find the log file ────────────────────────────────────────────────────────

LOG_FILE="${SCRIPT_DIR}/autoinst-log.txt"
if [[ ! -f "${LOG_FILE}" ]]; then
    # Fall back to searching testresults
    LOG_FILE=$(find "${RESULTS_DIR}" -name 'autoinst-log.txt' -print -quit 2>/dev/null || true)
fi

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: Cannot find autoinst-log.txt. Run capture-screenshots.sh first." >&2
    exit 1
fi

echo "==> Parsing log: ${LOG_FILE}"

mkdir -p "${NEEDLES_DIR}"

# ── Parse SNAP and NEEDLE markers ────────────────────────────────────────────

last_snap=""
count=0
skipped_json=0

while IFS= read -r line; do
    # Track the most recent SNAP (last unique frame captured)
    if [[ "${line}" =~ SNAP:\ (.+) ]]; then
        last_snap="${BASH_REMATCH[1]}"
        continue
    fi

    # On NEEDLE marker, pair it with the last snap
    if [[ "${line}" =~ NEEDLE:\ ([a-zA-Z0-9_-]+) ]]; then
        tag="${BASH_REMATCH[1]}"

        if [[ -z "${last_snap}" ]]; then
            echo "  WARN: No SNAP found before NEEDLE: ${tag}, skipping"
            continue
        fi

        if [[ ! -f "${last_snap}" ]]; then
            echo "  WARN: Frame file missing: ${last_snap} (for ${tag}), skipping"
            continue
        fi

        # Copy PNG (always overwrite — this is the whole point)
        cp "${last_snap}" "${NEEDLES_DIR}/${tag}.png"
        echo "  PNG:  ${tag}.png <- $(basename "${last_snap}")"

        # Generate default JSON if missing (or --force-json)
        json_file="${NEEDLES_DIR}/${tag}.json"
        if [[ ! -f "${json_file}" ]] || [[ "${FORCE_JSON}" == "true" ]]; then
            generate_default_json "${tag}" "${NEEDLES_DIR}/${tag}.png" "${json_file}"
            echo "  JSON: ${tag}.json (generated)"
        else
            skipped_json=$((skipped_json + 1))
        fi

        count=$((count + 1))
    fi
done < "${LOG_FILE}"

echo ""
echo "==> Done: ${count} needles updated"
if [[ ${skipped_json} -gt 0 ]]; then
    echo "    ${skipped_json} existing JSON files preserved (use --force-json to overwrite)"
fi
