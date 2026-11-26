# Loopy · Antigravity Desktop Pet for macOS

**English** · [简体中文](./README.zh-CN.md)

Loopy is a desktop pet for Google Antigravity. She wears a pink pig costume, jumps when you hover over her, and runs in the direction you drag her. Her toolbar lets you bring Antigravity forward or glance at recent conversations.

## Download for macOS

**[Download Loopy for macOS (ZIP, 4.03 MB)](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy-MacOS/releases/download/macos-universal/Loopy-macOS-Universal.zip)**

For Apple silicon and Intel Macs running macOS 12 or later. The ZIP includes the app, animations and Lua runtime. No source download or build tools are required.

1. Double-click `Loopy-macOS-Universal.zip` in Finder to extract it.
2. Drag `Loopy.app` into your Applications folder, then double-click it.

Loopy can keep you company on her own. Install Google Antigravity to use the pencil and voice buttons or display its recent conversations.

If macOS says it cannot verify Loopy the first time you open it, and you trust this download, go to **System Settings → Privacy & Security** and choose **Open Anyway** for Loopy. [Apple’s guide](https://support.apple.com/en-us/102445)

![Loopy in her pink pig costume](./Resources/Frames/0-0.png)

## Using Loopy

| Action | What happens |
| --- | --- |
| Hover over Loopy | She hops. Move the pointer away to end the animation. |
| Drag her left or right | She runs in that direction and stays where you drop her. She remembers her position the next time you open her. |
| Click or double-click her | Click to make her wave. Double-click to make her jump. |
| Click the pencil | Antigravity opens in one window. If a window is already open, Loopy brings it forward. |
| Click the sound wave | Loopy opens Antigravity and shows where to start voice input. |
| Click the chevron | Switch between live activity and recent conversation cards. Click a card for details. |
| Right-click her | Preview animations or quit Loopy. |

## Build from source

Loopy runs on Apple silicon and Intel Macs with macOS 12 or later. The project includes the Lua source and artwork. To build it, install Apple's Command Line Tools with `xcode-select --install` if needed, then run these commands from the repository root.

```sh
./build.sh
open ./build/Loopy.app
```

If Loopy is already running, right-click her and choose **退出 Loopy** before opening the new build. To launch her later from Finder, move `Loopy.app` into `~/Applications` and double-click it.

## Working on Loopy

| Area | Files |
| --- | --- |
| Mouse interaction, window position and menus | [LoopyMac.c](./src/LoopyMac.c) |
| Animation timing, running direction and gaze | [Motion.lua](./Resources/Motion.lua) |
| Toolbar, conversation cards and placement | [LoopyCards.h](./src/LoopyCards.h), [Placement.lua](./Resources/Placement.lua) |
| Conversation states, ordering and titles | [Conversation.lua](./Resources/Conversation.lua), [ActivityFeed.lua](./Resources/ActivityFeed.lua), [ConversationTitles.lua](./Resources/ConversationTitles.lua), [json.lua](./Resources/json.lua) |

To change the artwork, edit [the sprite sheet](./artwork/spritesheet.png), run `python3 tools/regenerate_art.py` with Pillow installed, and rebuild. The animation frames are in [Resources/Frames](./Resources/Frames) and the toolbar and card images are in [Resources/UI](./Resources/UI).

To run the animation checks with a Lua 5.1 interpreter, use the following command from the repository root.

```sh
lua -e 'print(dofile("tests/hover_checks.lua")("Resources/"))'
```

## Contributions

Codex helped Loopy open Antigravity in a single window, tested the hover and drag animations, and wrote the English and Chinese guides.
