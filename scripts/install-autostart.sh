#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
BIN_DIR="$PROJECT_DIR/bin"
SOURCE_BIN="$PROJECT_DIR/target/release/rm-native-viewer"
TARGET_BIN="$BIN_DIR/rm-native-viewer"
SOURCE_SIMPLE_LAUNCHER="$PROJECT_DIR/scripts/run-viewer.sh"
TARGET_SIMPLE_LAUNCHER="$BIN_DIR/rm-native-viewer-run"
TEMPLATE="$PROJECT_DIR/deploy/autostart/rm-native-viewer.desktop.in"
DEFAULT_CLIENT_ID="101"
AUTOSTART_DELAY="${RM_VIEWER_AUTOSTART_DELAY:-5}"
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=true
      ;;
    --default-client)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--default-client 缺少参数" >&2
        exit 1
      fi
      DEFAULT_CLIENT_ID=$1
      ;;
    --help|-h)
      cat <<'EOF'
用法: ./scripts/install-autostart.sh [--default-client 1|101] [--skip-build]

会安装两个 Startup Applications 条目：
  - RoboMaster Native Viewer (Client 1)
  - RoboMaster Native Viewer (Client 101)

默认启用 `101`，可用 --default-client 切换默认启用项。
默认会自动构建 release；如果你已经手动编译过，可加 --skip-build。
EOF
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$DEFAULT_CLIENT_ID" != "1" && "$DEFAULT_CLIENT_ID" != "101" ]]; then
  echo "非法默认 client id: $DEFAULT_CLIENT_ID (仅支持 1 或 101)" >&2
  exit 1
fi

if [[ "$SKIP_BUILD" != true ]]; then
  cargo build --release --manifest-path "$PROJECT_DIR/Cargo.toml"
fi

if [[ ! -x "$SOURCE_BIN" ]]; then
  echo "缺少 release 二进制: $SOURCE_BIN" >&2
  echo "先执行: cargo build --release" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_SIMPLE_LAUNCHER" ]]; then
  echo "缺少启动脚本: $SOURCE_SIMPLE_LAUNCHER" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$AUTOSTART_DIR"
cp "$SOURCE_BIN" "$TARGET_BIN"
cp "$SOURCE_SIMPLE_LAUNCHER" "$TARGET_SIMPLE_LAUNCHER"
chmod +x "$TARGET_BIN"
chmod +x "$TARGET_SIMPLE_LAUNCHER"

rm -f \
  "$BIN_DIR/rm-native-viewer-profile" \
  "$AUTOSTART_DIR/rm-native-viewer.desktop" \
  "$AUTOSTART_DIR/rm-native-viewer-official.desktop" \
  "$AUTOSTART_DIR/rm-native-viewer-lab.desktop" \
  "$AUTOSTART_DIR/rm-native-viewer-client-1.desktop" \
  "$AUTOSTART_DIR/rm-native-viewer-client-101.desktop"

install_desktop_entry() {
  local client_id=$1
  local name=$2
  local comment=$3
  local enabled=$4
  local desktop_file="$AUTOSTART_DIR/rm-native-viewer-client-${client_id}.desktop"
  local exec_line="env RM_VIEWER_STARTUP_DELAY=${AUTOSTART_DELAY} $TARGET_SIMPLE_LAUNCHER ${client_id}"

  sed \
    -e "s|%APP_NAME%|${name}|g" \
    -e "s|%APP_COMMENT%|${comment}|g" \
    -e "s|%EXEC_PATH%|${exec_line}|g" \
    -e "s|%WORK_DIR%|${PROJECT_DIR}|g" \
    -e "s|%AUTOSTART_ENABLED%|${enabled}|g" \
    "$TEMPLATE" > "$desktop_file"

  chmod 644 "$desktop_file"
  echo "已安装 Startup 项: $desktop_file"
  echo "  启动命令: $exec_line"
  echo "  默认启用: $enabled"
}

client_1_enabled=false
client_101_enabled=false
if [[ "$DEFAULT_CLIENT_ID" == "1" ]]; then
  client_1_enabled=true
else
  client_101_enabled=true
fi

install_desktop_entry \
  1 \
  "RoboMaster Native Viewer (Client 1)" \
  "Native decoder-side viewer autostart for client id 1" \
  "$client_1_enabled"

install_desktop_entry \
  101 \
  "RoboMaster Native Viewer (Client 101)" \
  "Native decoder-side viewer autostart for client id 101" \
  "$client_101_enabled"

echo "默认启用 client id: $DEFAULT_CLIENT_ID"