#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
BIN_DIR="$PROJECT_DIR/bin"
SOURCE_BIN="$PROJECT_DIR/target/release/rm-native-viewer"
TARGET_BIN="$BIN_DIR/rm-native-viewer"
SOURCE_LAUNCHER="$PROJECT_DIR/scripts/run-profile.sh"
TARGET_LAUNCHER="$BIN_DIR/rm-native-viewer-profile"
SOURCE_SIMPLE_LAUNCHER="$PROJECT_DIR/scripts/run-viewer.sh"
TARGET_SIMPLE_LAUNCHER="$BIN_DIR/rm-native-viewer-run"
TEMPLATE="$PROJECT_DIR/deploy/autostart/rm-native-viewer.desktop.in"
DEFAULT_PROFILE="official"
AUTOSTART_DELAY="${RM_VIEWER_AUTOSTART_DELAY:-5}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --default-profile)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--default-profile 缺少参数" >&2
        exit 1
      fi
      DEFAULT_PROFILE=$1
      ;;
    --help|-h)
      cat <<'EOF'
用法: ./scripts/install-autostart.sh [--default-profile official|lab]

会安装两个 Startup Applications 条目：
  - RoboMaster Native Viewer (Official)
  - RoboMaster Native Viewer (Lab)

默认启用 `official`，可用 --default-profile 切换默认启用项。
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

if [[ "$DEFAULT_PROFILE" != "official" && "$DEFAULT_PROFILE" != "lab" ]]; then
  echo "非法默认 profile: $DEFAULT_PROFILE (仅支持 official 或 lab)" >&2
  exit 1
fi

if [[ ! -x "$SOURCE_BIN" ]]; then
  echo "缺少 release 二进制: $SOURCE_BIN" >&2
  echo "先执行: cargo build --release" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_LAUNCHER" ]]; then
  echo "缺少 profile 启动脚本: $SOURCE_LAUNCHER" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_SIMPLE_LAUNCHER" ]]; then
  echo "缺少启动脚本: $SOURCE_SIMPLE_LAUNCHER" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$AUTOSTART_DIR"
cp "$SOURCE_BIN" "$TARGET_BIN"
cp "$SOURCE_LAUNCHER" "$TARGET_LAUNCHER"
cp "$SOURCE_SIMPLE_LAUNCHER" "$TARGET_SIMPLE_LAUNCHER"
chmod +x "$TARGET_BIN"
chmod +x "$TARGET_LAUNCHER"
chmod +x "$TARGET_SIMPLE_LAUNCHER"

install_desktop_entry() {
  local profile=$1
  local name=$2
  local comment=$3
  local enabled=$4
  local desktop_file="$AUTOSTART_DIR/rm-native-viewer-${profile}.desktop"
  local exec_line="env RM_VIEWER_STARTUP_DELAY=${AUTOSTART_DELAY} $TARGET_LAUNCHER ${profile}"

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

rm -f "$AUTOSTART_DIR/rm-native-viewer.desktop"

official_enabled=false
lab_enabled=false
if [[ "$DEFAULT_PROFILE" == "official" ]]; then
  official_enabled=true
else
  lab_enabled=true
fi

install_desktop_entry \
  official \
  "RoboMaster Native Viewer (Official)" \
  "Native decoder-side viewer for official 192.168.12.1 network" \
  "$official_enabled"

install_desktop_entry \
  lab \
  "RoboMaster Native Viewer (Lab)" \
  "Native decoder-side viewer for lab 10.42.0.1 network" \
  "$lab_enabled"

echo "默认启用 profile: $DEFAULT_PROFILE"