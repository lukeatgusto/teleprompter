# Teleprompter

A translucent, always-on-top teleprompter overlay for macOS. Reads markdown files and renders them as formatted text you can read while seeing through to content behind the window.

## Features

- **Translucent overlay** - See through to other windows behind the text
- **Click-through** - Click on windows behind the teleprompter without switching focus
- **Voice-driven scrolling** - Uses macOS speech recognition to follow along as you speak
- **Auto-scroll** - Constant-speed scrolling with adjustable rate
- **Markdown rendering** - Headers, bold, italic, lists, code blocks, links
- **Adjustable opacity** - Slider to control background transparency
- **Light/dark text** - Toggle between white and black text
- **Mirror mode** - Flip text for beam splitter setups
- **Resizable and draggable** - Position and size to your liking

## Install

Requires macOS with Xcode Command Line Tools (`xcode-select --install`).

### With Claude Code

```
/teleprompter install
```

### Manual

```bash
git clone https://github.com/lukezeller/teleprompter.git
cd teleprompter
swiftc teleprompter.swift -o teleprompter -framework Cocoa -framework WebKit -framework Speech -framework AVFoundation
```

## Usage

```bash
# Open with file picker
./teleprompter

# Open a specific file
./teleprompter path/to/script.md
```

## Controls

| Key | Action |
|-----|--------|
| Space | Play/pause auto-scroll |
| Up/Down | Adjust scroll speed |
| [ / ] | Decrease/increase font size |
| - / = | Decrease/increase opacity |
| V | Toggle voice-driven scrolling |
| R | Reset to top |
| M | Mirror mode |
| O | Open file |
| Q / Esc | Quit |

## Toolbar

- **Open** - Browse for a markdown file
- **Mic** - Toggle voice-driven scrolling (follows your speech)
- **Opacity slider** - Adjust background transparency
- **A** - Toggle white/black text
- **?** - Show keyboard shortcuts
