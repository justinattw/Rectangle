# JRectangle

A personal fork of [Rectangle](https://github.com/rxhanson/Rectangle) for macOS 14+.

## Installation

Install the full Xcode app (not just Command Line Tools), open it once and complete its setup, then run:

```bash
git clone https://github.com/justinattw/Rectangle.git
cd Rectangle
make install
open /Applications/JRectangle.app
```

Approve the Keychain prompts on the first build, choosing **Always Allow** for `codesign`. Builds reuse a local signing identity.

Quit JRectangle before reinstalling. The installer backs up the previous app and installs to `/Applications/JRectangle.app`.

To package a disk image instead, run `make dmg`. Open `build/JRectangle.dmg` and drag JRectangle to Applications before launching it. Builds are for personal use and are not Apple-notarised, so downloaded copies may be blocked on other Macs.

### Permissions

- **Accessibility:** Enable JRectangle in **System Settings > Privacy & Security > Accessibility** (on macOS 27, **Device Control and Data Access**) so it can control windows.
- **Automation:** Only needed for moving windows between desktops. Allow control of **System Events** when prompted.

### If installation fails

| Problem | What to do |
|---|---|
| Xcode tools, licence or SDK error | Finish Xcode setup and select it under **Xcode > Settings > Locations > Command Line Tools**. |
| Dependency download fails | Building requires internet access to fetch MASShortcut. Check your connection and retry. |
| Signing fails or Keychain prompts repeat | Unlock your login keychain. Check that **JRectangle Local Development** has its private key and is trusted for code signing in Keychain Access. Do not delete the identity just to rebuild. |
| Cannot write to `/Applications` | Use `make dmg` and copy the app with Finder, approving its permissions prompt. Do not run the build with `sudo`. |
| macOS blocks a downloaded copy | Only if you trust its source, use **System Settings > Privacy & Security > Open Anyway** if available. Do not disable Gatekeeper. See [Apple's guidance](https://support.apple.com/en-us/102445). |
| Permission is enabled but window control fails after reinstalling | Quit JRectangle, remove its old Accessibility entry, add `/Applications/JRectangle.app` again and reopen it. |
| Moving between desktops fails | Enable **JRectangle > System Events** under **Privacy & Security > Automation**, and enable the default **Control-Left/Right Arrow** shortcuts under **Keyboard > Keyboard Shortcuts > Mission Control**. |

## Features

- **Snapping and tiling:** Drag to screen edges or use shortcuts, including row and column layouts.
- **Display profiles:** Override settings by monitor resolution, inheriting unchanged values from **Default**.
- **Window switching:** Option-Tab cycles visible windows on the current Space.
- **Stacking:** Independent horizontal and vertical offsets, a window list and cycle shortcuts. Turn off **Only stack windows of the same size** to stack different fractions on the same side.
- **Movement and resizing:** Configurable steps, margins and fractions.
- **Mouse shortcuts:** Bind side buttons to window actions.
- **Experimental:** Window animations and shortcuts for moving windows between desktops.

The menu bar shows only the main Shortcuts group. In Shortcuts settings, additional actions are listed under **⋯** and **Extra**.

## Configuration

Settings live in `~/.config/jrectangle/config.json`. Share this file directly or symlink it from your dotfiles repository.

Use **App Settings > Configuration File** to change the path, or **Show Config in Finder** to locate it. Custom paths are per machine. Reopen after changing location, and quit before editing the JSON directly.

See [hidden preferences](TerminalCommands.md) for additional options.

## Credits

Based on Rectangle and its contributors. Uses [MASShortcut](https://github.com/rxhanson/MASShortcut). See [LICENSE](LICENSE).
