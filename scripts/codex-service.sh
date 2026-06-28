#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/ccc/ai/codex-tools"
BIN="$ROOT/codex-tools-proxyd"
LOG_OUT="$ROOT/nohup-codex-proxy.out"
LOG_ERR="$ROOT/nohup-codex-proxy.err"
LABEL="com.ccc.codex-tools-proxyd"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

usage() {
  cat <<EOF
usage: $(basename "$0") <command> [args]

commands:
  start              kill old process and start proxyd
  stop               stop proxyd process
  restart            restart proxyd process
  status             show proxyd process status
  tail               tail proxyd stdout log
  logs [lines]       show last N lines of stdout log, default 100
  install            install and load launchd service
  uninstall          unload and remove launchd service
  service-status     show launchd service status
  service-restart    restart launchd service
EOF
}

ensure_log_exists() {
  local log_file="$1"
  if [[ ! -f "$log_file" ]]; then
    echo "log file not found: $log_file"
    exit 1
  fi
}

start_proc() {
  pkill -f "$BIN" 2>/dev/null || true
  nohup "$BIN" > "$LOG_OUT" 2>&1 &
  local pid=$!
  echo "started codex-tools-proxyd, pid=$pid, log=$LOG_OUT"
  disown "$pid" 2>/dev/null || true
}

stop_proc() {
  local pids
  pids="$(pgrep -f "$BIN" || true)"

  if [[ -z "$pids" ]]; then
    echo "codex-tools-proxyd is not running"
    return 0
  fi

  pkill -f "$BIN"
  echo "stopped codex-tools-proxyd: $pids"
}

status_proc() {
  local pids
  pids="$(pgrep -f "$BIN" || true)"

  if [[ -z "$pids" ]]; then
    echo "status: stopped"
    return 0
  fi

  echo "status: running"
  echo "pid(s):"
  printf '%s\n' "$pids"

  if [[ -f "$LOG_OUT" ]]; then
    echo "log: $LOG_OUT"
  fi
}

install_service() {
  mkdir -p "$PLIST_DIR"

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$ROOT</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$LOG_OUT</string>

  <key>StandardErrorPath</key>
  <string>$LOG_ERR</string>
</dict>
</plist>
EOF

  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl load "$PLIST_PATH"

  echo "installed launchd service: $PLIST_PATH"
  echo "label: $LABEL"
}

uninstall_service() {
  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "uninstalled launchd service: $PLIST_PATH"
}

service_status() {
  if [[ ! -f "$PLIST_PATH" ]]; then
    echo "service not installed: $PLIST_PATH"
    return 0
  fi

  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    echo "service: loaded"
    echo "label: $LABEL"
    echo "plist: $PLIST_PATH"
    return 0
  fi

  echo "service: installed but not loaded"
  echo "label: $LABEL"
  echo "plist: $PLIST_PATH"
}

service_restart() {
  if [[ ! -f "$PLIST_PATH" ]]; then
    echo "service not installed: $PLIST_PATH"
    exit 1
  fi

  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl load "$PLIST_PATH"
  echo "service restarted: $LABEL"
}

main() {
  local cmd="${1:-}"
  local lines="${LINES:-100}"

  case "$cmd" in
    start)
      start_proc
      ;;
    stop)
      stop_proc
      ;;
    restart)
      stop_proc || true
      start_proc
      ;;
    status)
      status_proc
      ;;
    tail)
      ensure_log_exists "$LOG_OUT"
      exec tail -f "$LOG_OUT"
      ;;
    logs)
      ensure_log_exists "$LOG_OUT"
      if [[ "${2:-}" != "" ]]; then
        lines="$2"
      fi
      exec tail -n "$lines" "$LOG_OUT"
      ;;
    install)
      install_service
      ;;
    uninstall)
      uninstall_service
      ;;
    service-status)
      service_status
      ;;
    service-restart)
      service_restart
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
