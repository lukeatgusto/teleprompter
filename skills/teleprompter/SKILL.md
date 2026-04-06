---
name: teleprompter
description: Use when user says "teleprompter", wants to install or run the teleprompter overlay app, or says /teleprompter. Handles download, compile, install, and launch of the macOS teleprompter tool.
---

# Teleprompter

Translucent, always-on-top teleprompter overlay for macOS with voice-driven scrolling. Reads markdown files.

## Commands

`/teleprompter` or `/teleprompter install` - Install or update and launch.
`/teleprompter run` - Launch (install first if needed).
`/teleprompter uninstall` - Remove the app.

## Install Flow

1. Check if already installed at `~/.local/bin/teleprompter`
2. If not, clone from GitHub and compile:

```bash
# Clone
git clone https://github.com/lukeatgusto/teleprompter.git /tmp/teleprompter-build

# Compile
swiftc /tmp/teleprompter-build/teleprompter.swift \
  -o /tmp/teleprompter-build/teleprompter \
  -framework Cocoa -framework WebKit -framework Speech -framework AVFoundation

# Install
mkdir -p ~/.local/bin
cp /tmp/teleprompter-build/teleprompter ~/.local/bin/teleprompter

# Cleanup
rm -rf /tmp/teleprompter-build
```

3. If already installed, check for updates:

```bash
# Clone to temp, compile, replace
git clone https://github.com/lukeatgusto/teleprompter.git /tmp/teleprompter-build
swiftc /tmp/teleprompter-build/teleprompter.swift \
  -o ~/.local/bin/teleprompter \
  -framework Cocoa -framework WebKit -framework Speech -framework AVFoundation
rm -rf /tmp/teleprompter-build
```

## Launch Flow

Run in background so it doesn't block the conversation:

```bash
~/.local/bin/teleprompter &
```

Or with a specific file:

```bash
~/.local/bin/teleprompter path/to/script.md &
```

## Uninstall Flow

```bash
rm ~/.local/bin/teleprompter
```

## Prerequisites

If `swiftc` is not available, tell the user to run:
```bash
xcode-select --install
```

## Troubleshooting

- **"can't be opened" Gatekeeper warning**: Won't happen - compiled from source locally.
- **Mic not working**: User needs to grant microphone permission when prompted.
- **swiftc not found**: Need Xcode Command Line Tools installed.
