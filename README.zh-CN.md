# Loopy · Google Antigravity 桌面宠物（macOS & Windows）

[English](./README.md) · **简体中文**

Loopy 穿着粉色小猪装，支持 **macOS** 与 **Windows**。鼠标移到她身上时会跳起来，按住她往哪边拖，她就朝哪边跑。她身下有一排工具按钮，可以一键拉起 Google Antigravity，也可以查看最近的对话。

## 下载安装

- **[下载 macOS 版 Loopy（ZIP，4.03 MB）](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy/releases/download/v1.4/Loopy-macOS-Universal.zip)** — 支持 macOS 12 及以上的 Apple 芯片和 Intel Mac。
- **[下载 Windows 版 Loopy（ZIP，6.92 MB）](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy/releases/download/v1.4/Loopy-Windows-x64.zip)** — 免安装 64 位便携包（内含未修改的 Rainmeter 4.5.28，及 `ThirdParty/` 中的 GPL 许可证与源码包）。

两个安装包均已内置完整动画与 Lua 运行环境，无需另下源码或安装编译工具。Loopy 可以独立运行；使用写字、语音按钮或查看最近对话需要本机安装 Google Antigravity。

### macOS 安装步骤
1. 在访达中双击 `Loopy-macOS-Universal.zip` 解压。
2. 把 `Loopy.app` 拖进「应用程序」文件夹，再双击启动。
3. 如果首次打开时 macOS 提示无法验证 Loopy，确认信任后前往「系统设置 → 隐私与安全性」，找到 Loopy 并点「仍要打开」。[Apple 官方说明](https://support.apple.com/zh-cn/102445)

### Windows 安装步骤
1. 将 `Loopy-Windows-x64.zip` 解压到固定目录（例如 `%LOCALAPPDATA%\Programs\LoopyCompanion\`）。
2. 双击 `Loopy-Windows\Rainmeter.exe` 启动（或为它创建桌面快捷方式，并将起始位置设为 `Loopy-Windows` 所在目录）。

![穿着粉色小猪装的 Loopy](./Resources/Frames/0-0.png)

## 和 Loopy 互动

| 操作 | 效果 |
| --- | --- |
| 鼠标移到 Loopy 身上 | 她会跳起来，移开鼠标就会停下。 |
| 按住她向左或向右拖动 | 她会朝拖动方向跑，松手后停在原处。下次打开时，她还会出现在这里。 |
| 单击或双击她 | 单击挥手，双击跳跃。 |
| 点写字按钮 | 单窗口打开 Antigravity（Windows 版会优先沿用桌面/开始菜单中自定义的 `Antigravity.lnk` 启动方式）；若已打开则直接切回前台。 |
| 点声波按钮 | 打开 Antigravity，并提示你从哪里开始语音输入。 |
| 点折叠箭头 | 在实时动态和最近对话卡片之间切换。点一张卡片可以查看详情。 |
| 右键点她 | 预览动作，或选择「退出 Loopy」。 |

## 从源码编译

### macOS

需要 macOS 12+ 并安装 Apple 命令行工具（`xcode-select --install`）：

```sh
./build.sh
open ./build/Loopy.app
```

如果 Loopy 已经在运行，先右键点她选择「退出 Loopy」，再打开刚编译的应用。

### Windows

需要 Python 3 和便携版 Rainmeter 4.5.28 目录：

```powershell
python tools/build_windows.py --rainmeter-dir <Rainmeter-4.5.28-目录> --zip
```

若需对外二次分发，可加 `--third-party-dir <目录>` 一并打包 Rainmeter 的 GPL 许可证与源码归档。

## 修改 Loopy

| 想改什么 | 对应文件 |
| --- | --- |
| macOS 鼠标交互、窗口位置和菜单 | [LoopyMac.c](./src/LoopyMac.c) |
| macOS 工具栏、对话卡片和拉起逻辑 | [LoopyCards.h](./src/LoopyCards.h) |
| Windows 皮肤、Lua 桥接、悬停传感与启动器 | [Loopy.ini](./windows/Skins/Loopy/Loopy.ini)、[Activity.ini](./windows/Skins/Loopy/Activity/Activity.ini)、[Loopy.lua](./windows/Skins/Loopy/@Resources/Loopy.lua)、[Pointer.ps1](./windows/Skins/Loopy/@Resources/Pointer.ps1)、[LaunchAntigravity.ps1](./windows/Skins/Loopy/@Resources/LaunchAntigravity.ps1) |
| 共用动画时序、奔跑方向和视线 | [Motion.lua](./Resources/Motion.lua) |
| 共用会话状态、排序、标题与卡片布局 | [Conversation.lua](./Resources/Conversation.lua)、[ActivityFeed.lua](./Resources/ActivityFeed.lua)、[ConversationTitles.lua](./Resources/ConversationTitles.lua)、[Placement.lua](./Resources/Placement.lua)、[json.lua](./Resources/json.lua) |

要改造型，可以编辑[动作图集](./artwork/spritesheet.png)，用装有 Pillow 的 Python 运行 `python3 tools/regenerate_art.py`，再重新构建对应平台包。动画帧在 [Resources/Frames](./Resources/Frames)，工具栏和气泡图片在 [Resources/UI](./Resources/UI)。

如果装有 Lua 5.1 解释器，可以在仓库根目录运行以下命令检查动画：

```sh
lua -e 'print(dofile("tests/hover_checks.lua")("Resources/"))'
```

## 贡献

Codex 与 Antigravity 协助完成了 macOS 与 Windows 双平台支持、Antigravity 2.35.2 冷启动单窗口修复、Windows 代理快捷方式兼容、悬停/拖动动画验证及中英文文档编写。
