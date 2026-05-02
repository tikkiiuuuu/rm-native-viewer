#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <official|lab> [额外参数...]" >&2
  exit 1
fi

PROFILE=$1
shift

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR=$(cd -- "$SCRIPT_DIR/../bin" && pwd)
VIEWER_BIN="$BIN_DIR/rm-native-viewer"

if [[ ! -x "$VIEWER_BIN" ]]; then
  echo "缺少 viewer 二进制: $VIEWER_BIN" >&2
  exit 1
fi

BIND_ADDR=${RM_VIEWER_BIND:-}
FFMPEG_BIN=${RM_VIEWER_FFMPEG:-}
MQTT_PORT=${RM_VIEWER_MQTT_PORT:-3333}
MQTT_TOPIC=${RM_VIEWER_MQTT_TOPIC:-CustomByteBlock}
CLIENT_ID=${RM_VIEWER_CLIENT_ID:-1}
STARTUP_DELAY=${RM_VIEWER_STARTUP_DELAY:-0}

case "$PROFILE" in
  official)
    ALLOW_SOURCE=${RM_VIEWER_OFFICIAL_SOURCE:-192.168.12.1}
    MQTT_HOST=${RM_VIEWER_OFFICIAL_MQTT_HOST:-192.168.12.1}
    ;;
  lab)
    ALLOW_SOURCE=${RM_VIEWER_LAB_SOURCE:-10.42.0.1}
    MQTT_HOST=${RM_VIEWER_LAB_MQTT_HOST:-10.42.0.1}
    ;;
  *)
    echo "未知 profile: $PROFILE (仅支持 official 或 lab)" >&2
    exit 1
    ;;
esac

args=()
if [[ -n "$BIND_ADDR" ]]; then
  args+=("--bind" "$BIND_ADDR")
fi
if [[ -n "$ALLOW_SOURCE" ]]; then
  args+=("--allow-source" "$ALLOW_SOURCE")
fi
if [[ -n "$FFMPEG_BIN" ]]; then
  args+=("--ffmpeg" "$FFMPEG_BIN")
fi
if [[ "${RM_VIEWER_DISABLE_MQTT:-0}" == "1" ]]; then
  args+=("--no-mqtt")
else
  args+=(
    "--mqtt-host" "$MQTT_HOST"
    "--mqtt-port" "$MQTT_PORT"
    "--mqtt-topic" "$MQTT_TOPIC"
    "--mqtt-client-id" "$CLIENT_ID"
  )
fi

if [[ "$STARTUP_DELAY" =~ ^[0-9]+$ ]] && (( STARTUP_DELAY > 0 )); then
  sleep "$STARTUP_DELAY"
fi

exec "$VIEWER_BIN" "${args[@]}" "$@"