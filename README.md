# rm-native-viewer

`rm-native-viewer` 是一个原生 Rust 解码端，不依赖浏览器或网页前端，专门用于 RoboMaster 2026 部署模式下的低带宽 `0x0310` 自定义客户端视频链路。

当前版本已经按正式链路工作：

- 通过 MQTT 订阅 `CustomByteBlock`
- 把 `0x0310` 的 300 字节 `PV31` 分片重组为 H264 字节流
- 调用系统 `ffmpeg` 解码
- 在原生窗口中显示画面并叠加状态信息
- 对非视频 `0x0310` 数据兼容 telemetry v1 解析
- 保留 UDP 3334 + HEVC 作为旧实验链路 fallback

## 功能概览

- 官方主链路：MQTT `CustomByteBlock` -> `0x0310` -> `PV31` -> H264
- telemetry fallback：同一条 `0x0310` 链路上兼容解析状态结构体
- 旧链路兼容：UDP 3334 + HEVC
- 原生窗口显示：无浏览器依赖
- headless 烟测：适合 CI、本地回放和远端部署自检
- official / lab 双 profile 启动

## 目录结构

```text
rm-native-viewer/
├── Cargo.toml
├── src/
├── scripts/
├── deploy/
└── README.md
```

说明：

- `src/`：Rust 主程序与 `PV31` / telemetry 解析逻辑
- `scripts/`：profile 启动、部署辅助脚本
- `deploy/`：桌面自启动和 systemd 相关模板

## 环境要求

- Ubuntu Linux
- Rust stable（建议使用最新 stable）
- 系统 `ffmpeg`
- Wayland 或 X11 图形环境

推荐依赖安装：

```bash
sudo apt update
sudo apt install -y ffmpeg pkg-config libxkbcommon-dev
curl https://sh.rustup.rs -sSf | sh
```

## 编译

```bash
cargo build --release
```

生成的主程序位于：

```text
target/release/rm-native-viewer
```

## 运行

默认直接运行：

```bash
cargo run --release
```

默认行为：

- UDP 监听 `0.0.0.0:3334`
- MQTT 连接 `192.168.12.1:3333`
- topic 为 `CustomByteBlock`
- 默认输入格式为 `h264`

常用完整参数：

```bash
cargo run --release -- \
  --bind 0.0.0.0:3334 \
  --allow-source 192.168.12.1 \
  --mqtt-host 192.168.12.1 \
  --mqtt-port 3333 \
  --mqtt-topic CustomByteBlock \
  --mqtt-client-id 1 \
  --input-format h264
```

## 命令行参数

- `--bind <addr:port>`：UDP 监听地址，默认 `0.0.0.0:3334`
- `--allow-source <ip>`：限制 UDP 来源 IP
- `--width <n>`：显示宽度，默认 `1280`
- `--height <n>`：显示高度，默认 `720`
- `--ffmpeg <path>`：ffmpeg 路径，默认 `ffmpeg`
- `--mqtt-host <host>`：MQTT 地址，默认 `192.168.12.1`
- `--mqtt-port <port>`：MQTT 端口，默认 `3333`
- `--mqtt-topic <topic>`：topic，默认 `CustomByteBlock`
- `--mqtt-client-id <id>`：客户端 ID
- `--input-format <fmt>`：`h264` 或 `hevc`
- `--no-mqtt`：关闭 MQTT，仅保留 UDP 视频输入
- `--headless-seconds <n>`：无窗口烟测

## 支持的链路

### 1. 正式链路

这是当前主通路：

- 输入：MQTT `CustomByteBlock`
- 负载：官方 `0x0310`
- 业务封装：`PV31`
- 视频编码：H264

`PV31` 固定占满 `0x0310` 的 300 字节：

- 24 字节头：`magic/version/codec/flags/sequence/stream_ms/payload_bytes/checksum`
- 276 字节视频净荷

设计目标：

- 50Hz 发送
- 理论总带宽约 15KB/s
- 实际视频净流建议控制在约 12KB/s 内

### 2. telemetry fallback

如果 `CustomByteBlock.data` 不是 `PV31` 视频分片，程序会回退为 telemetry v1 解析，用于在画面上叠加：

- 相机在线状态
- gimbal 在线状态与模式
- `frame_seq` / 分辨率 / FPS
- `exposure` / `gain`
- `yaw` / `pitch` / `yaw_vel` / `pitch_vel`
- `bullet_speed` / `bullet_count`
- 状态文本

### 3. 旧实验链路

保留 UDP 3334 + HEVC 兼容模式。

如果你在接旧 sender，要显式加：

```bash
--input-format hevc
```

## Profile 启动

内置两个 profile：

- `official`：`192.168.12.1`
- `lab`：`10.42.0.1`

直接运行：

```bash
./scripts/run-profile.sh official
./scripts/run-profile.sh lab
```

环境变量覆盖：

- `RM_VIEWER_OFFICIAL_SOURCE`
- `RM_VIEWER_OFFICIAL_MQTT_HOST`
- `RM_VIEWER_LAB_SOURCE`
- `RM_VIEWER_LAB_MQTT_HOST`

其他运行环境变量：

- `RM_VIEWER_BIND`
- `RM_VIEWER_ALLOW_SOURCE`
- `RM_VIEWER_FFMPEG`
- `RM_VIEWER_MQTT_HOST`
- `RM_VIEWER_MQTT_PORT`
- `RM_VIEWER_MQTT_TOPIC`
- `RM_VIEWER_CLIENT_ID`
- `RM_VIEWER_INPUT_FORMAT`
- `RM_VIEWER_DISABLE_MQTT`

## 烟测

本地或远端无窗口自检：

```bash
cargo run --release -- --headless-seconds 8 --allow-source 127.0.0.1
```

如果 8 秒内成功解码至少一帧，程序返回成功。

适合配合录包回放器使用，例如：

- 本地起 MQTT 服务
- 本地起 `replay-official-link`
- viewer 用 `--headless-seconds` 做验流

## 部署

先编译 release：

```bash
cargo build --release
```

把整个目录复制到目标机器后执行：

```bash
./scripts/install-autostart.sh
```

该脚本会：

- 复制 release 二进制到 `bin/`
- 复制 profile 启动脚本
- 安装桌面自启动项

支持设置默认 profile：

```bash
./scripts/install-autostart.sh --default-profile official
./scripts/install-autostart.sh --default-profile lab
```

临时手动启动：

```bash
./bin/rm-native-viewer
./bin/rm-native-viewer-profile official
./bin/rm-native-viewer-profile lab
```

## 常见问题

### 1. 一开始提示 `Invalid data found when processing input`

这是正常现象。订阅发生在码流中途时，可能先收到非关键帧，等到 SPS/PPS/IDR 后会自动恢复。

### 2. 看不到视频但 MQTT 已连接

优先检查：

- 当前发送端是不是 H264
- `--input-format` 是否匹配
- `CustomByteBlock` topic 是否正确
- 发送端是否真的在发 `PV31`

### 3. 只想测 MQTT 主链路，不要 UDP 干扰

可以继续保留默认 UDP 监听，也可以通过部署时只接入 MQTT 来使用；UDP 不会影响 `PV31` 主链路解析。
