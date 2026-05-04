#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

if [[ -n "${RM_VIEWER_BIN:-}" ]]; then
  VIEWER_BIN=$RM_VIEWER_BIN
elif [[ -x "$SCRIPT_DIR/rm-native-viewer" ]]; then
  VIEWER_BIN="$SCRIPT_DIR/rm-native-viewer"
elif [[ -x "$PROJECT_DIR/target/release/rm-native-viewer" ]]; then
  VIEWER_BIN="$PROJECT_DIR/target/release/rm-native-viewer"
elif [[ -x "$PROJECT_DIR/bin/rm-native-viewer" ]]; then
  VIEWER_BIN="$PROJECT_DIR/bin/rm-native-viewer"
else
  echo "缺少 viewer 二进制" >&2
  echo "先执行: cargo build --release" >&2
  exit 1
fi

PROFILE=${RM_VIEWER_PROFILE:-official}
if [[ $# -gt 0 && ( "$1" == "official" || "$1" == "lab" ) ]]; then
  PROFILE=$1
  shift
fi

CLIENT_ID=${RM_VIEWER_CLIENT_ID:-}
if [[ $# -gt 0 && "$1" != --* ]]; then
  CLIENT_ID=$1
  shift
fi

case "$PROFILE" in
  official)
    MQTT_HOST=${RM_VIEWER_MQTT_HOST:-192.168.12.1}
    CLIENT_ID=${CLIENT_ID:-101}
    ;;
  lab)
    MQTT_HOST=${RM_VIEWER_MQTT_HOST:-10.42.0.1}
    CLIENT_ID=${CLIENT_ID:-1}
    ;;
  *)
    echo "未知 profile: $PROFILE (仅支持 official 或 lab)" >&2
    exit 1
    ;;
esac

args=()
if [[ "$MQTT_HOST" != "192.168.12.1" ]]; then
  args+=("--mqtt-host" "$MQTT_HOST")
fi
if [[ -n "$CLIENT_ID" ]]; then
  args+=("--mqtt-client-id" "$CLIENT_ID")
fi

STARTUP_DELAY=${RM_VIEWER_STARTUP_DELAY:-0}
if [[ "$STARTUP_DELAY" =~ ^[0-9]+$ ]] && (( STARTUP_DELAY > 0 )); then
  sleep "$STARTUP_DELAY"
fi

exec "$VIEWER_BIN" "${args[@]}" "$@"