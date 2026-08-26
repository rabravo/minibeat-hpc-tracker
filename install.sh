#!/usr/bin/env bash
# install.sh — MiniBeat HPC Tracker installer
#
# Usage (from the repo root after cloning):
#
#     ./install.sh
#
# By default each step's output is captured to a timestamped log directory
# and a spinner shows elapsed time. To stream all output live:
#
#     VERBOSE=1 ./install.sh
#
# Environment variable overrides:
#
#     ENV_PREFIX   Path for the conda environment
#                  (default: <repo>/../envs/minibeat-hpc)
#     DATA_ROOT    Where job uploads and outputs are stored
#                  (default: <repo>/WebJobs)
#     VERBOSE      Set to 1 to stream all output live (default: 0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# OS detection — drives env strategy in setup_server.sh and run_server.sh
# ---------------------------------------------------------------------------
case "$(uname -s 2>/dev/null)" in
  Linux)               _PLATFORM="linux"   ;;
  Darwin)              _PLATFORM="macos"   ;;
  MINGW*|CYGWIN*|MSYS*) _PLATFORM="windows" ;;
  *)                   _PLATFORM="linux"   ;;
esac
export _PLATFORM

# Linux/HPC: prefix env (overridable); macOS/Windows: named env "minibeat-hpc"
if [ "$_PLATFORM" = "linux" ]; then
  export ENV_PREFIX="${ENV_PREFIX:-$SCRIPT_DIR/../envs/minibeat-hpc}"
fi

export DATA_ROOT="${DATA_ROOT:-$SCRIPT_DIR/WebJobs}"
VERBOSE="${VERBOSE:-0}"

LOG_DIR="$SCRIPT_DIR/install_logs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

TOTAL_STEPS=2

# ---------------------------------------------------------------------------
# Terminal helpers
# ---------------------------------------------------------------------------
COLS=$(tput cols 2>/dev/null || echo 72)

hr() { printf '%*s\n' "$COLS" '' | tr ' ' '─'; }

_SPINNER_PID=""

start_spinner() {
    local label="$1"
    (
        local frames=('|' '/' '-' '\')
        local i=0
        local start=$SECONDS
        while true; do
            local elapsed=$(( SECONDS - start ))
            printf "\r  %s  %s  [%02d:%02d]" \
                "${frames[i]}" "$label" "$(( elapsed / 60 ))" "$(( elapsed % 60 ))"
            i=$(( (i + 1) % 4 ))
            sleep 0.2
        done
    ) &
    _SPINNER_PID=$!
}

stop_spinner() {
    if [ -n "$_SPINNER_PID" ] && kill -0 "$_SPINNER_PID" 2>/dev/null; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null || true
    fi
    _SPINNER_PID=""
    printf '\r%*s\r' "$COLS" ""
}

trap 'stop_spinner' EXIT

run_step() {
    local num="$1" label="$2"
    shift 2
    local logfile="$LOG_DIR/step${num}.log"
    local start=$SECONDS rc=0

    hr
    printf "  Step %s/%d — %s\n" "$num" "$TOTAL_STEPS" "$label"
    hr
    echo

    if [ "$VERBOSE" = "1" ]; then
        "$@" 2>&1 | tee "$logfile" || true
        rc=${PIPESTATUS[0]}
    else
        printf "  Output → %s\n\n" "$logfile"
        start_spinner "$label"
        "$@" > "$logfile" 2>&1 || rc=$?
        stop_spinner
    fi

    if [ "$rc" -ne 0 ]; then
        printf "  ✗ Step %s FAILED (exit %d)\n\n" "$num" "$rc"
        if [ "$VERBOSE" != "1" ]; then
            printf "  Last 30 lines of log:\n\n"
            tail -30 "$logfile" >&2
            printf "\n  Full log: %s\n" "$logfile"
        fi
        exit "$rc"
    fi

    local elapsed=$(( SECONDS - start ))
    printf "  ✓ Step %s complete (%02d:%02d)\n\n" \
        "$num" "$(( elapsed / 60 ))" "$(( elapsed % 60 ))"
}

# ---------------------------------------------------------------------------
# Preflight: conda
# ---------------------------------------------------------------------------
if ! command -v conda >/dev/null 2>&1; then
    echo "conda not found — attempting: module load miniconda3"
    if type module >/dev/null 2>&1; then
        module load miniconda3 2>/dev/null || true
    fi
fi
if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda not found. Install Miniconda and re-run." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Preflight: submodule
# ---------------------------------------------------------------------------
if [ ! -f "$SCRIPT_DIR/minibeat-tracker/setup.py" ] && \
   [ ! -f "$SCRIPT_DIR/minibeat-tracker/pyproject.toml" ]; then
    echo "Initialising minibeat-tracker submodule..."
    git -C "$SCRIPT_DIR" submodule update --init
fi

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
hr
printf "  MiniBeat HPC Tracker — Installer\n"
printf "  Logs: %s\n" "$LOG_DIR"
hr
echo
printf "  Platform:    %s\n" "$_PLATFORM"
if [ "$_PLATFORM" = "linux" ]; then
  printf "  Conda env:   prefix  → %s\n" "${ENV_PREFIX:-<repo>/../envs/minibeat-hpc}"
else
  printf "  Conda env:   named   → minibeat-hpc\n"
fi
printf "  DATA_ROOT:   %s\n" "$DATA_ROOT"
printf "  VERBOSE:     %s\n" "$VERBOSE"
echo
printf "  Tip: VERBOSE=1 ./install.sh streams all output live.\n"
echo

# ---------------------------------------------------------------------------
# Step 1 — Conda environment
# ---------------------------------------------------------------------------
run_step 1 "Creating minibeat-hpc conda environment" \
    "$SCRIPT_DIR/setup_server.sh"

# ---------------------------------------------------------------------------
# Step 2 — Create job data directory
# ---------------------------------------------------------------------------
run_step 2 "Creating job data directory" \
    mkdir -p "$DATA_ROOT"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
hr
printf "  Installation complete.\n\n"
printf "  To start the server:\n\n"
printf "    ./run_server.sh\n\n"
printf "  Then on your laptop:\n\n"
printf "    ssh -N -L 8766:localhost:8766 \$USER@<this-host>\n"
printf "    open http://localhost:8766/\n\n"
printf "  Logs for this run: %s\n" "$LOG_DIR"
hr
