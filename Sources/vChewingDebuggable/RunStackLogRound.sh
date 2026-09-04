#!/bin/bash
# RunStackLogRound.sh — unattended serial memory round for vChewingDebuggable.
#
# Launches the diagnostics host with MallocStackLogging=1 and drives a serial
# SettingsUI / SettingsCocoa open-close cycle over the vchewingdbg:// URL scheme.
# At each phase it snapshots telemetry (sample) and a malloc_history -callTree
# dump (mh).  Each mh capture runs to completion (polled via the app log) before
# the next phase starts — the in-app isMhBusy guard would otherwise silently skip
# overlapping captures and produce huge files.  All output lands in ~/Library/Logs/ :
#   vChewingDebuggable.log                    chronological sample timeline
#   vChewingDebuggable-mh-<stamp>.txt         per-phase allocation call trees
#
# NOTE: under MallocStackLogging the in-app malloc-zone telemetry reads zero and
# the `internal` figures are inflated by stack-log buffers — rely on the .mh files.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_BIN="$REPO_ROOT/Build/Products/Debug/vChewingDebuggable.app/Contents/MacOS/vChewingDebuggable"
LOG_FILE="$HOME/Library/Logs/vChewingDebuggable.log"

killall vChewingDebuggable 2>/dev/null
sleep 1
env MallocStackLogging=1 "$APP_BIN" >/dev/null 2>&1 &
APP_PID=$!
echo "launched pid=$APP_PID"
sleep 10
open "vchewingdbg://reset"; sleep 1

# Fire one mh capture and block until a new dump file appears (atomic write).
mh_and_wait() { # $1 = tag
  local before now
  before=$(ls "$HOME"/Library/Logs/vChewingDebuggable-mh-*.txt 2>/dev/null | wc -l | tr -d ' ')
  open "vchewingdbg://mh?tag=$1"
  for _ in $(seq 1 240); do
    now=$(ls "$HOME"/Library/Logs/vChewingDebuggable-mh-*.txt 2>/dev/null | wc -l | tr -d ' ')
    [ "$now" -gt "$before" ] && return 0
    sleep 1
  done
  echo "TIMEOUT waiting for mh capture: $1"
}

phase() { # $1 = tag; sample then mh-and-wait
  open "vchewingdbg://sample?tag=$1"; sleep 2
  mh_and_wait "$1"
}

echo "[1/5] baseline"; phase "01-baseline"
echo "[2/5] open SettingsUI"; open "vchewingdbg://openSettingsUI"; sleep 8; phase "02-open-SUI"
echo "[3/5] close SettingsUI"; open "vchewingdbg://closeSettingsUI"; sleep 8; phase "03-close-SUI"
echo "[4/5] open+close SettingsCocoa"; open "vchewingdbg://openSettingsCocoa"; sleep 6; open "vchewingdbg://closeSettingsCocoa"; sleep 8; phase "05-final"

killall vChewingDebuggable 2>/dev/null
echo "=== sample timeline ==="
grep "internal=" "$LOG_FILE"
echo "=== malloc_history dumps ==="
ls -la "$HOME"/Library/Logs/vChewingDebuggable-mh-*.txt 2>/dev/null
