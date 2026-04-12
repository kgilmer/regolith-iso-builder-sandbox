#!/usr/bin/env python3
"""Quick needle validation — compare a needle against a screenshot and report similarity.

Usage:
    ./check-needle.py needles/setup-welcome screenshot.png
    ./check-needle.py needles/setup-welcome                    # uses the needle's own PNG as reference

Compares each match region defined in the needle JSON, computing a similarity
score per region (0.0–1.0). Reports pass/fail based on the needle's threshold.

This lets you check if a needle will match without running the full test suite.
"""

import json
import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    missing = []
    try:
        from PIL import Image
    except ImportError:
        missing.append("Pillow")
    try:
        import numpy
    except ImportError:
        missing.append("numpy")
    print(f"ERROR: Missing dependencies: {', '.join(missing)}", file=sys.stderr)
    print(f"Install with: pip install {' '.join(missing)}", file=sys.stderr)
    sys.exit(1)


def load_needle(needle_path):
    """Load needle JSON. Accepts path with or without extension."""
    if needle_path.endswith(".png"):
        needle_path = needle_path[:-4]
    elif needle_path.endswith(".json"):
        needle_path = needle_path[:-5]

    json_path = needle_path + ".json"
    png_path = needle_path + ".png"

    if not os.path.exists(json_path):
        print(f"ERROR: Needle JSON not found: {json_path}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(png_path):
        print(f"ERROR: Needle PNG not found: {png_path}", file=sys.stderr)
        sys.exit(1)

    with open(json_path) as f:
        data = json.load(f)

    return png_path, data


def region_similarity(needle_img, target_img, region):
    """Compute normalized cross-correlation similarity for a region."""
    x, y = region["xpos"], region["ypos"]
    w, h = region["width"], region["height"]

    # Crop the region from both images
    needle_crop = np.array(needle_img.crop((x, y, x + w, y + h)), dtype=np.float64)
    target_crop = np.array(target_img.crop((x, y, x + w, y + h)), dtype=np.float64)

    if needle_crop.shape != target_crop.shape:
        return 0.0

    # Flatten to 1D
    a = needle_crop.flatten()
    b = target_crop.flatten()

    # Normalized cross-correlation
    a_mean = a - a.mean()
    b_mean = b - b.mean()
    denom = (np.linalg.norm(a_mean) * np.linalg.norm(b_mean))
    if denom == 0:
        return 1.0 if np.array_equal(a, b) else 0.0

    ncc = np.dot(a_mean, b_mean) / denom
    # Map from [-1, 1] to [0, 1]
    return max(0.0, (ncc + 1.0) / 2.0)


def main():
    if len(sys.argv) < 2:
        print("Usage: check-needle.py <needle> [screenshot.png]", file=sys.stderr)
        print("  e.g.: ./check-needle.py needles/setup-welcome testresults/screenshot.png", file=sys.stderr)
        sys.exit(1)

    needle_path = sys.argv[1]
    png_path, data = load_needle(needle_path)

    if len(sys.argv) >= 3:
        target_path = sys.argv[2]
    else:
        # Self-check: compare needle against itself (should score ~1.0)
        target_path = png_path
        print(f"(No screenshot provided — self-checking needle against its own PNG)\n")

    if not os.path.exists(target_path):
        print(f"ERROR: Screenshot not found: {target_path}", file=sys.stderr)
        sys.exit(1)

    needle_img = Image.open(png_path).convert("RGB")
    target_img = Image.open(target_path).convert("RGB")

    tag = data.get("tags", ["?"])[0]
    print(f"Needle: {tag}")
    print(f"  PNG:        {png_path}")
    print(f"  Target:     {target_path}")
    print(f"  Image size: {needle_img.size[0]}x{needle_img.size[1]} vs {target_img.size[0]}x{target_img.size[1]}")
    print()

    match_regions = [a for a in data.get("area", []) if a["type"] == "match"]
    exclude_regions = [a for a in data.get("area", []) if a["type"] == "exclude"]

    if not match_regions:
        print("  WARNING: No match regions defined in needle JSON")
        sys.exit(1)

    all_pass = True
    for i, region in enumerate(match_regions):
        threshold = region.get("match", 85) / 100.0
        score = region_similarity(needle_img, target_img, region)
        passed = score >= threshold
        status = "PASS" if passed else "FAIL"
        if not passed:
            all_pass = False

        print(f"  Region {i+1}: ({region['xpos']},{region['ypos']} {region['width']}x{region['height']})")
        print(f"    Score:     {score:.4f}  ({score*100:.1f}%)")
        print(f"    Threshold: {threshold:.2f}  ({region.get('match', 85)}%)")
        print(f"    Result:    {status}")
        print()

    if exclude_regions:
        print(f"  ({len(exclude_regions)} exclude region(s) defined — not scored)")
        print()

    overall = "PASS" if all_pass else "FAIL"
    print(f"Overall: {overall}")
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
