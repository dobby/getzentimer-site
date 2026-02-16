#!/usr/bin/env bash
#
# Convert PNG/JPG images to WebP for the ZenTimer site.
# Run locally or in CI before deploying.
#
# Requirements: cwebp (brew install webp / apt-get install webp)

set -euo pipefail

QUALITY=80
DIRS=(
  "assets/img/appstore-captures"
  "assets/img/screenshots"
)

command -v cwebp >/dev/null 2>&1 || { echo "Error: cwebp not found. Install with: brew install webp (macOS) or apt-get install webp (Linux)"; exit 1; }

converted=0
skipped=0

for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || continue

  for src in "$dir"/*.png "$dir"/*.jpg "$dir"/*.jpeg; do
    [ -f "$src" ] || continue

    webp="${src%.*}.webp"

    # Skip if WebP exists and is newer than the source
    if [ -f "$webp" ] && [ "$webp" -nt "$src" ]; then
      skipped=$((skipped + 1))
      continue
    fi

    echo "Converting: $src -> $webp"
    cwebp -q "$QUALITY" "$src" -o "$webp" -quiet
    converted=$((converted + 1))
  done
done

echo "Done. Converted: $converted, Skipped (up-to-date): $skipped"
