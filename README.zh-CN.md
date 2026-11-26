# Loopy · Google Antigravity 的 macOS 桌面宠物

[English](./README.md) · **简体中文**

Loopy 穿着粉色小猪装，鼠标移到她身上时会跳起来，按住她往哪边拖，她就朝哪边跑。她身下有一排工具按钮，可以打开 Google Antigravity，也可以查看最近的对话。

## 下载安装

**[下载 macOS 版 Loopy（ZIP，4.03 MB）](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy-MacOS/releases/download/macos-universal/Loopy-macOS-Universal.zip)**

支持 macOS 12 及以上的 Apple 芯片和 Intel Mac。压缩包里已包含应用、动画和 Lua 运行环境，无需另下源码或安装编译工具。

1. 在访达中双击 `Loopy-macOS-Universal.zip` 解压。
2. 把 `Loopy.app` 拖进「应用程序」文件夹，再双击启动。

Loopy 可以独立运行。要用写字和语音按钮，或查看最近的对话，还需要安装 Google Antigravity。

如果首次打开时 macOS 提示无法验证 Loopy，确认你信任下载来源后，可以前往「系统设置 → 隐私与安全性」，找到 Loopy 并点「仍要打开」。[Apple 官方说明](https://support.apple.com/zh-cn/102445)

![穿着粉色小猪装的 Loopy](./Resources/Frames/0-0.png)

## 和 Loopy 互动

| 操作 | 效果 |
| --- | --- |
| 鼠标移到 Loopy 身上 | 她会跳起来，移开鼠标就会停下。 |
| 按住她向左或向右拖动 | 她会朝拖动方向跑，松手后停在原处。下次打开时，她还会出现在这里。 |
| 单击或双击她 | 单击挥手，双击跳跃。 |
| 点写字按钮 | 打开一个 Antigravity 窗口。如果已经打开，就回到现有窗口。 |
| 点声波按钮 | 打开 Antigravity，并提示你从哪里开始语音输入。 |
| 点折叠箭头 | 在实时动态和最近对话卡片之间切换。点一张卡片可以查看详情。 |
| 右键点她 | 预览动作，或选择「退出 Loopy」。 |

## 从源码编译

Loopy 支持 macOS 12 及以上的 Apple 芯片和 Intel Mac。项目已包含 Lua 源码和美术素材。如果还没有安装 Apple 命令行工具，先运行 `xcode-select --install`，然后在仓库根目录运行以下命令。

```sh
./build.sh
open ./build/Loopy.app
```

如果 Loopy 已经在运行，先右键点她，选择「退出 Loopy」，再打开刚编译的应用。你也可以把 `Loopy.app` 移到个人应用程序文件夹 `~/Applications`，以后直接在访达里双击启动。

## 修改 Loopy

| 想改什么 | 对应文件 |
| --- | --- |
| 鼠标交互、窗口位置和菜单 | [LoopyMac.c](./src/LoopyMac.c) |
| 动画时序、奔跑方向和视线 | [Motion.lua](./Resources/Motion.lua) |
| 工具栏、对话卡片和布局 | [LoopyCards.h](./src/LoopyCards.h)、[Placement.lua](./Resources/Placement.lua) |
| 会话状态、排序和标题 | [Conversation.lua](./Resources/Conversation.lua)、[ActivityFeed.lua](./Resources/ActivityFeed.lua)、[ConversationTitles.lua](./Resources/ConversationTitles.lua)、[json.lua](./Resources/json.lua) |

要改造型，可以编辑[动作图集](./artwork/spritesheet.png)，用装有 Pillow 的 Python 运行 `python3 tools/regenerate_art.py`，再重新编译。动画帧在 [Resources/Frames](./Resources/Frames)，工具栏和气泡图片在 [Resources/UI](./Resources/UI)。

如果装有 Lua 5.1 解释器，可以在仓库根目录运行以下命令检查动画。

```sh
lua -e 'print(dofile("tests/hover_checks.lua")("Resources/"))'
```

## 贡献

Codex 参与了从桌宠打开 Antigravity 的单窗口功能开发，验证了悬停跳跃和拖动奔跑的动画，并编写了中英文使用说明。
