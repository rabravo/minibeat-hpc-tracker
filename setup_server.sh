#!/usr/bin/env bash
# setup_server.sh — create the minibeat-hpc conda environment.
#
# Behaviour is OS-aware:
#   Linux  — prefix env at <repo>/../envs/minibeat-hpc  (HPC convention)
#   macOS  — named env   "minibeat-hpc"                 (standard conda)
#   Windows (Git Bash / Cygwin) — same as macOS
#
# Override the prefix on Linux:
#   ENV_PREFIX=/my/path ./setup_server.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
case "$(uname -s 2>/dev/null)" in
  Linux)               _PLATFORM="linux"   ;;
  Darwin)              _PLATFORM="macos"   ;;
  MINGW*|CYGWIN*|MSYS*) _PLATFORM="windows" ;;
  *)                   _PLATFORM="linux"   ;;
esac

# ---------------------------------------------------------------------------
# Conda check
# ---------------------------------------------------------------------------
if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found — attempting: module load miniconda3"
  if type module >/dev/null 2>&1; then
    module load miniconda3 2>/dev/null || true
  fi
fi
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found in PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Create environment
# ---------------------------------------------------------------------------
if [ "$_PLATFORM" = "linux" ]; then
  ENV_PREFIX="${ENV_PREFIX:-$SCRIPT_DIR/../envs/minibeat-hpc}"
  if [ -d "$ENV_PREFIX/conda-meta" ]; then
    echo "Environment already exists at $ENV_PREFIX -- skipping."
    echo "To rebuild: rm -rf $ENV_PREFIX && ./setup_server.sh"
    exit 0
  fi
  echo "Creating conda environment (prefix)..."
  echo "  Target: $ENV_PREFIX"
  echo ""
  conda env create --file environment.yml --prefix "$ENV_PREFIX"
  echo ""
  echo "Environment created at $ENV_PREFIX"
else
  if conda env list 2>/dev/null | grep -qE "^minibeat-hpc[[:space:]]"; then
    echo "Named environment 'minibeat-hpc' already exists -- skipping."
    echo "To rebuild: conda env remove -n minibeat-hpc && ./setup_server.sh"
    exit 0
  fi
  echo "Creating conda environment (named)..."
  echo "  Name: minibeat-hpc"
  echo ""
  conda env create -n minibeat-hpc --file environment.yml
  echo ""
  echo "Environment 'minibeat-hpc' created."
fi

echo ""
echo "To start the server:"
echo "  ./run_server.sh"
