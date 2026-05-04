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

exec "$VIEWER_BIN" "$@"