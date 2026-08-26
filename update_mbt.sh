#!/usr/bin/env bash
# update_mbt.sh — pull the latest minibeat-tracker and bump the submodule pointer.
#
# Run this from the minibeat-hpc-tracker repo root whenever minibeat-tracker
# has been updated and you want those changes reflected here.
#
# Usage:
#   ./update_mbt.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Fetching latest minibeat-tracker..."
git -C "$SCRIPT_DIR" submodule update --remote minibeat-tracker

echo "Staging submodule pointer..."
git -C "$SCRIPT_DIR" add minibeat-tracker

if git -C "$SCRIPT_DIR" diff --cached --quiet; then
    echo "minibeat-tracker is already up to date — nothing to commit."
    exit 0
fi

git -C "$SCRIPT_DIR" commit -m "bump minibeat-tracker submodule to latest"
git -C "$SCRIPT_DIR" push

echo ""
echo "Done. minibeat-tracker submodule updated and pushed."
