#!/usr/bin/env bash
# Download, verify and extract the PRISM-2026 dataset.
#
#   ./scripts/download.sh                    # everything (3 days + view trees)
#   ./scripts/download.sh 2026.07.11         # one day only (+ view trees)
#   NO_VIEWS=1 ./scripts/download.sh         # sessions only, skip the view trees
#
# The data lives in this repository's GitHub Release assets, not in the git tree.
# Override with environment variables:
#   REPO  target repository (default illiard1209/PRISM-2026-Dataset)
#   TAG   release tag       (default v1.0.0)
#   DEST  download location (default ./data)
set -euo pipefail

REPO="${REPO:-illiard1209/PRISM-2026-Dataset}"
TAG="${TAG:-v1.0.0}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"
DEST="${DEST:-./data}"
ROOT="PRISM_2026.07.10-12"

# 2026.07.10 is split by host group because Release assets are capped at 2 GiB per file.
# Each part extracts independently and merges into the same tree.
declare -A PARTS=(
  ["2026.07.10"]="PRISM_sessions_2026.07.10_part1.tar.zst PRISM_sessions_2026.07.10_part2.tar.zst"
  ["2026.07.11"]="PRISM_sessions_2026.07.11.tar.zst"
  ["2026.07.12"]="PRISM_sessions_2026.07.12.tar.zst"
)

DATES=("$@")
if [ ${#DATES[@]} -eq 0 ]; then
  DATES=(2026.07.10 2026.07.11 2026.07.12)
fi

command -v curl >/dev/null || { echo "curl is required." >&2; exit 1; }
command -v zstd >/dev/null || { echo "zstd is required: apt install zstd" >&2; exit 1; }

mkdir -p "$DEST"; cd "$DEST"

fetch_and_extract() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "==> $f already present — skipping download"
  else
    echo "==> downloading $f"
    curl -fL --retry 3 -C - -o "$f" "${BASE}/${f}"
  fi
  echo "==> verifying $f"
  grep " ${f}\$" SHA256SUMS | sha256sum -c - || {
    echo "checksum mismatch for $f — delete it and download again" >&2; exit 1; }
  echo "==> extracting $f"
  tar -I zstd -xf "$f"
}

echo "==> SHA256SUMS"
curl -fL --retry 3 -o SHA256SUMS "${BASE}/SHA256SUMS"

for d in "${DATES[@]}"; do
  for f in ${PARTS[$d]}; do
    fetch_and_extract "$f"
  done
done

# The view trees are relative symlinks into sessions/, so they must be extracted last.
if [ "${NO_VIEWS:-}" != "1" ]; then
  fetch_and_extract "PRISM_views.tar.zst"
fi

echo
echo "Done: $(pwd)/$ROOT"
echo "  sessions          : $(find "$ROOT/sessions" -name '*.pcap' 2>/dev/null | wc -l) sessions"
if [ -d "$ROOT/byproduct" ]; then
  broken=$(find "$ROOT/byproduct" "$ROOT/byproduct_process" -xtype l 2>/dev/null | wc -l)
  echo "  byproduct         : $(find "$ROOT/byproduct" -name '*.pcap' 2>/dev/null | wc -l) (application view)"
  echo "  byproduct_process : $(find "$ROOT/byproduct_process" -name '*.pcap' 2>/dev/null | wc -l) (process view)"
  if [ "$broken" -gt 0 ]; then
    echo
    echo "  Warning: $broken dangling symlinks."
    echo "  This is expected if you downloaded only some days — only those days resolve."
    echo "  On a filesystem without symlink support, materialize them as real files:"
    echo "    python3 scripts/materialize_views.py $(pwd)/$ROOT --mode hardlink"
  fi
fi
