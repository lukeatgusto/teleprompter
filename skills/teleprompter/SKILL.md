---
name: teleprompter
description: Use when user says "teleprompter", wants to present or read a script, asks to display markdown as an overlay, wants a floating text reader, says "open this as a teleprompter", wants to practice a speech or presentation, needs a prompter for a video call, or says /teleprompter. Handles download, compile, install, and launch of the macOS teleprompter overlay tool.
---

# Teleprompter

Translucent, always-on-top teleprompter overlay for macOS with voice-driven scrolling. Reads markdown files.

## Commands

`/teleprompter` or `/teleprompter install` - Install or update and launch.
`/teleprompter run` - Launch (install first if needed).
`/teleprompter uninstall` - Remove the app.

## Prerequisite Checks

Run these checks BEFORE attempting install. Stop and tell the user if any fail.

```bash
# 1. Must be macOS
uname -s  # Must output "Darwin"

# 2. Must have swiftc (Xcode Command Line Tools)
which swiftc

# 3. Must have git
which git
```

If `swiftc` is missing, tell the user to run this and wait for it to complete:
```bash
xcode-select --install
```

If `uname` is not Darwin, tell the user this only works on macOS.

## Install Flow

1. Run prerequisite checks above
2. Check if already installed at `~/.local/bin/teleprompter`
3. Clean up any leftover build directory from a previous attempt:

```bash
rm -rf /tmp/teleprompter-build
```

4. Clone and compile:

```bash
# Clone
git clone https://github.com/lukeatgusto/teleprompter.git /tmp/teleprompter-build

# Compile (this takes ~10-30 seconds)
swiftc /tmp/teleprompter-build/teleprompter.swift \
  -o /tmp/teleprompter-build/teleprompter \
  -framework Cocoa -framework WebKit -framework Speech -framework AVFoundation

# Install
mkdir -p ~/.local/bin
cp /tmp/teleprompter-build/teleprompter ~/.local/bin/teleprompter

# Cleanup
rm -rf /tmp/teleprompter-build
```

5. Verify the binary works:

```bash
~/.local/bin/teleprompter --help 2>&1 || echo "Binary exists and is executable"
```

## Update Flow

Same as install - clone, compile, replace:

```bash
rm -rf /tmp/teleprompter-build
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

## Troubleshooting

- **Compile fails with "no such module"**: Xcode CLT may be outdated. Run `xcode-select --install` or `softwareupdate -l` to check for updates.
- **Mic not working**: User needs to grant microphone permission when prompted on first use.
- **Window doesn't appear**: Make sure no other teleprompter process is running: `pkill teleprompter`
- **Binary not found after install**: The skill always uses the full path `~/.local/bin/teleprompter`. If the user wants to run it manually from any terminal, they need `~/.local/bin` in their PATH.
