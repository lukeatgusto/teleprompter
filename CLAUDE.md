# CLAUDE.md

## About This Repo

This is a Claude Code plugin for a macOS teleprompter overlay. It's published to the Gusto gists marketplace as `teleprompter@gusto-gists`.

## Version Bumps

**Every commit that changes `teleprompter.swift` or `skills/teleprompter/SKILL.md` must bump the version in `.claude-plugin/plugin.json`.** This is how users know to update.

Use semver:
- **Patch** (1.0.0 → 1.0.1): Bug fixes, wording tweaks, small behavior changes
- **Minor** (1.0.1 → 1.1.0): New features, new controls, new skill commands
- **Major** (1.1.0 → 2.0.0): Breaking changes (changed CLI args, removed features)

Include the version bump in the same commit as the changes, not as a separate commit.

## Key Files

- `.claude-plugin/plugin.json` — Plugin manifest (name, version, description)
- `skills/teleprompter/SKILL.md` — Install/run/update skill for Claude Code
- `teleprompter.swift` — The entire app (single file)
- `test.md` — Sample markdown for testing

## Build & Test

```bash
mkdir -p ~/.local/bin
swiftc teleprompter.swift -o ~/.local/bin/teleprompter -framework Cocoa -framework WebKit -framework Speech -framework AVFoundation
~/.local/bin/teleprompter test.md
```

**Note:** Do not run the compiled binary from `~/Documents` — macOS TCC protections will SIGKILL it. Always compile to `~/.local/bin/` or `/tmp/`.

## Rules

- Keep it as a single Swift file. No Xcode project, no package managers.
- The compiled binary is gitignored. Users compile from source.
- The skill uses full path `~/.local/bin/teleprompter` — don't assume PATH includes it.
