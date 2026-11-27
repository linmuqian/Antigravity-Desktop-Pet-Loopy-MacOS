# Loopy · Antigravity Desktop Pet

**English** · [简体中文](./README.zh-CN.md)

Loopy is a desktop pet for Google Antigravity on **macOS** and **Windows**. She wears a pink pig costume, hops when you hover over her, and runs in the direction you drag her. Her toolbar lets you bring Antigravity forward or glance at recent conversations.

## Download

- **[Download Loopy for macOS (ZIP, 4.03 MB)](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy/releases/download/v1.4/Loopy-macOS-Universal.zip)** — Apple silicon & Intel Macs running macOS 12 or later.
- **[Download Loopy for Windows (ZIP, 6.92 MB)](https://github.com/linmuqian/Antigravity-Desktop-Pet-Loopy/releases/download/v1.4/Loopy-Windows-x64.zip)** — Portable 64-bit Windows bundle (includes unmodified Rainmeter 4.5.28 and GPL source/license in `ThirdParty/`).

No source download or build tools are required for either release archive. Loopy can keep you company on her own; install Google Antigravity to use the pencil and voice buttons or display its recent conversations.

### macOS installation
1. Double-click `Loopy-macOS-Universal.zip` in Finder to extract it.
2. Drag `Loopy.app` into your Applications folder, then double-click it.
3. If macOS says it cannot verify Loopy the first time you open it, and you trust this download, go to **System Settings → Privacy & Security** and choose **Open Anyway**. [Apple’s guide](https://support.apple.com/en-us/102445)

### Windows installation
1. Extract `Loopy-Windows-x64.zip` to a permanent folder (for example `%LOCALAPPDATA%\Programs\LoopyCompanion\`).
2. Run `Loopy-Windows\Rainmeter.exe` (or create a desktop shortcut pointing to it with its "Start in" folder set to `Loopy-Windows`).

![Loopy in her pink pig costume](./Resources/Frames/0-0.png)

## Using Loopy

| Action | What happens |
| --- | --- |
| Hover over Loopy | She hops. Move the pointer away to end the animation. |
| Drag her left or right | She runs in that direction and stays where you drop her. She remembers her position the next time you open her. |
| Click or double-click her | Click to make her wave. Double-click to make her jump. |
| Click the pencil | Antigravity opens in one window (honoring your desktop/Start Menu `Antigravity.lnk` if customized). If a window is already open, Loopy brings it forward. |
| Click the sound wave | Loopy opens Antigravity and shows where to start voice input. |
| Click the chevron | Switch between live activity and recent conversation cards. Click a card for details. |
| Right-click her | Preview animations or quit Loopy. |

## Build from source

### macOS

Requires Apple's Command Line Tools (`xcode-select --install`) on macOS 12 or later:

```sh
./build.sh
open ./build/Loopy.app
```

If Loopy is already running, right-click her and choose **退出 Loopy** before opening the new build.

### Windows

Requires Python 3 and a portable/extracted copy of Rainmeter 4.5.28:

```powershell
python tools/build_windows.py --rainmeter-dir <path-to-Rainmeter-4.5.28> --zip
```

Pass `--third-party-dir <path>` to include `Rainmeter-LICENSE.txt` and `Rainmeter-4.5.28-source.zip` when redistributing.

## Working on Loopy

| Area | Files |
| --- | --- |
| macOS host: mouse interaction, window position and menus | [LoopyMac.c](./src/LoopyMac.c) |
| macOS host: toolbar, conversation cards and launch | [LoopyCards.h](./src/LoopyCards.h) |
| Windows host: skins, Lua bridge, pointer & launcher | [Loopy.ini](./windows/Skins/Loopy/Loopy.ini), [Activity.ini](./windows/Skins/Loopy/Activity/Activity.ini), [Loopy.lua](./windows/Skins/Loopy/@Resources/Loopy.lua), [Pointer.ps1](./windows/Skins/Loopy/@Resources/Pointer.ps1), [LaunchAntigravity.ps1](./windows/Skins/Loopy/@Resources/LaunchAntigravity.ps1) |
| Shared animation timing, running direction and gaze | [Motion.lua](./Resources/Motion.lua) |
| Shared conversation states, ordering, titles and card layout | [Conversation.lua](./Resources/Conversation.lua), [ActivityFeed.lua](./Resources/ActivityFeed.lua), [ConversationTitles.lua](./Resources/ConversationTitles.lua), [Placement.lua](./Resources/Placement.lua), [json.lua](./Resources/json.lua) |

To change the artwork, edit [the sprite sheet](./artwork/spritesheet.png), run `python3 tools/regenerate_art.py` with Pillow installed, and rebuild. The animation frames are in [Resources/Frames](./Resources/Frames) and the toolbar and card images are in [Resources/UI](./Resources/UI).

To run the animation checks with a Lua 5.1 interpreter, use the following command from the repository root:

```sh
lua -e 'print(dofile("tests/hover_checks.lua")("Resources/"))'
```

## Contributions

Codex and Antigravity helped Loopy support both macOS and Windows, fix the Antigravity 2.35.2 cold-start dual-window issue, preserve custom proxy launcher shortcuts on Windows, verify hover/drag animations, and write the English and Chinese guides.
