# JRectangle

English | [简体中文](README.zh-Hans.md)

JRectangle is a personal fork of [Rectangle](https://github.com/rxhanson/Rectangle), a macOS window manager based on Spectacle.

## What JRectangle adds

- **Display profiles:** Override supported settings by display resolution, with inherited values and overrides shown in Settings.
- **Window switching:** Option-Tab cycles visible windows on the current Space. Configure it under **Shortcuts**; Command-Tab remains the macOS app switcher.
- **Experimental desktop moves:** Assign shortcuts to move the focused window to the previous or next desktop.
- **Movement and resizing:** Directional move shortcuts nudge windows by a configurable step. Width and height resize shortcuts are available in the main shortcut list.
- **Stacking and margins:** Set horizontal and vertical overlap offsets and display-edge margins independently.
- **Personal branding:** JRectangle has its own name and icon. Automatic and manual update checks have been removed.

JRectangle retains Rectangle's existing snapping, tiling, stacked-window cycling and other window-management features.

<img width="612" height="810" alt="image" src="https://github.com/user-attachments/assets/c088d1e2-3661-4041-ac30-95da89ac4a41" />

## System Requirements

JRectangle supports macOS v14+.

## Installation

Install Xcode, then clone this repository and run:

```bash
git clone https://github.com/justinattw/Rectangle.git
cd Rectangle
make install
open /Applications/JRectangle.app
```

`make install` builds the Release app and installs it in `/Applications`. Quit JRectangle before reinstalling; the installer keeps the previous app in a backup folder in `/Applications`. The installer requires write access to that folder. macOS may ask you to grant Accessibility permission again after a rebuild.

Settings are stored per macOS account. Use **App Settings > Export** and **Import** to transfer them to another account or Mac.

## How to use it

The [keyboard shortcuts](https://support.apple.com/guide/mac-help/what-are-those-symbols-shown-in-menus-cpmh0011/mac) are self explanatory, but the snap areas can use some explanation if you've never used them on Windows or other window management apps.

Drag a window to the edge of the screen. When the mouse cursor reaches the edge of the screen, you'll see a footprint that JRectangle will attempt to resize and move the window to when the click is released.

| Snap Area                                              | Resulting Action                       |
|--------------------------------------------------------|----------------------------------------|
| Left or right edge                                     | Left or right half                     |
| Top                                                    | Maximize                               |
| Corners                                                | Quarter in respective corner           |
| Left or right edge, just above or below a corner       | Top or bottom half                     |
| Bottom left, center, or right third                    | Respective third                       |
| Bottom left or right third, then drag to bottom center | First or last two thirds, respectively |

In **Behavior** > **Extras**, enable **Animate windows** for smooth window resizing, or in **Snap Areas**, enable **Blur footprint** for a blurred snap preview. Both are off by default. Animated snapping keeps the selected edge or center aligned when an app limits its window size or aspect ratio. Dragging a snapped window starts restoring its previous size as the window begins moving, and a quick release lets the remaining restore animation continue. Far-right title-bar grabs can still show visible jumps. Title-bar double-click maximize/restore follows the same animation setting and timing as snapping. Window animation has been tested in known scenarios, but remains experimental because repeatedly updating the window's size and position during the transition may cause issues in some edge cases.

In **Shortcuts**, use the gear beside **Move Left** or **Larger Width** to set **Move and width resize step** for all four move shortcuts and width-only resize shortcuts. In **Behavior**, horizontal and vertical display edge margins are separate from **Gaps between windows**. Changing an edge margin sets both edges on that axis equally; existing asymmetric and notch-specific margins remain unchanged until edited. Existing main-screen-only and notch settings still apply.

The experimental **Previous Desktop** and **Next Desktop** shortcuts are below the display shortcuts and are unassigned by default. They simulate dragging the focused window's title bar while switching desktops, and follow the window. Enable the default Control-Left and Control-Right Mission Control shortcuts in **System Settings > Keyboard > Keyboard Shortcuts > Mission Control**, and allow JRectangle to control System Events when prompted. Accessibility permission is also required. Release the shortcut and mouse buttons, and avoid moving the mouse during the transfer. The pointer may remain on the window's title bar after a move. Full-screen windows, windows without a usable title bar, customized system desktop shortcuts, and some apps are not supported. At the end of the desktop list there may be no adjacent desktop; macOS does not provide a public way to confirm that the move succeeded.

The display profile picker lists connected resolutions and labels a connected built-in display. Select a resolution to edit its overrides; blue labels mark overridden settings, including collapsed sections. Reset removes the selected profile's overrides. Profiles with the same resolution share settings.

### Tile windows in rows or columns

In **Behavior** > **Extras**, enable **Show Extra shortcuts in menu** to include Rows and Columns in the **Tiling** submenu. Their keyboard shortcuts remain available when the submenu is hidden.

In Settings > **Shortcuts**, expand **⋯** and then **Extra** to assign separate keys to **Tile in Rows** and **Tile in Columns**. Each action arranges ordinary windows in the current Space on the display containing the focused window, including windows covered by others. When no ordinary window is focused, the display under the mouse pointer is used instead. **Tile All** uses the same display-selection rule. Normally, windows on another display stay in place, and an empty target display does nothing. When JRectangle's combined-display mode is enabled and macOS "Displays have separate Spaces" is disabled, Rows and Columns instead tile across the combined display area. Rows run from top to bottom; columns run from left to right. Within either direction, JRectangle uses the windows' upper-left positions before moving them to choose their order.

From an unrecognized layout, the first press starts with one window per row or column. Repeating the action cycles through distinct grid layouts. Click the gear button next to **Tile in Rows** to set **Maximum windows per column** and **Maximum windows per row**, which control the cycle independently. Both default to 3 and are independent of the single-window **Repeated commands** setting. Set either limit to 1 to keep that action's original one-window-per-row-or-column behavior. Existing saved limits are preserved.

Windows are balanced across occupied rows or columns, with no deliberately empty cells. For example, six windows with a column limit of 3 cycle through six columns of one, three columns of two, two columns of three, then repeat. Five windows cycle through column populations `1,1,1,1,1`, `2,2,1`, and `3,2`. A column with fewer windows still fills its full height; rows behave the same way across their full width. Duplicate layouts are skipped, so four windows with a limit of 3 alternate between four groups of one and two groups of two. Limits above the number of windows add no layouts.

Columns have equal widths and rows have equal heights, within one display pixel, when the apps allow it. The grid fills the selected work area inside macOS reservations (such as the menu bar and Dock) and JRectangle's configured screen-edge gaps. App size restrictions take precedence: if two columns share 1000 pixels and one requires at least 600, a feasible allocation is 600/400. If no allocation satisfies all app restrictions, JRectangle still attempts the layout, which may leave a gap or overlap. If an app does not respond in time, the layout may remain partial.

Moving or resizing a window, opening or closing one, or changing screen-edge gaps does not rearrange windows automatically. The next press of the same action reapplies its active grid layout using the current windows and their positions. A press that would leave the layout unchanged advances immediately. Lowering a limit below the active layout uses the greatest allowed layout on the next press. JRectangle keeps the active layout only while it is running. After a restart, the first press advances from an intact, recognizable grid; otherwise it starts with one window per row or column.

The Todo window is excluded using the same rules as JRectangle's other multi-window actions. The bands respect the existing Todo sidebar reservation. For example, with 1000 pixels available and a 200-pixel sidebar reservation, the other windows tile within the remaining 800 pixels while Todo stays in place.

### Cycle stacked windows

When several windows are snapped to the same area, such as three windows on the left half, only the front one is visible. In Settings > **Behavior** > **Stacked Windows**, assign keys to **Cycle stacked windows** and **Cycle stacked windows backward**. Each press brings forward one window from the stack that the focused window belongs to.

A window is in the stack when it sits at the same position as the window focused at the first press, or is offset from it by **Offset window position on overlap**, whatever its size. With **Only stack windows of the same size** on, it must also be the same size (within 24 points in width and height, so terminal windows that snap to whole character cells still count), so a maximized window that shares a corner with a half is not in that half's stack. The stacked window list follows the same setting. **Cycle stacked windows** first brings forward the window at the back of the stack; **Cycle stacked windows backward** first brings forward the window just behind the front one. Repeated presses visit every window in the stack. Pressing either shortcut while a window outside the stack is focused starts over from that window's stack. When the focused window has nothing stacked with it, JRectangle beeps.

Set horizontal and vertical overlap offsets independently in **Stacked Windows**. A window only moves on an axis when there is enough room inside the usable display area.

### Mouse button shortcuts

A window action's shortcut can be a mouse button instead of a key, such as one of the side buttons found on many mice. The side buttons pair well with **Cycle stacked windows** and **Cycle stacked windows backward**. To assign one, click the action's shortcut field in Settings, either on the **Shortcuts** tab or in **Behavior** > **Stacked Windows**, then press the middle button or an extra button with the pointer over the Settings window. Hold any of ⌃, ⌥, ⇧ and ⌘ while pressing to include them, just as in a keyboard shortcut. Each action has one shortcut, so a mouse button replaces the action's keyboard shortcut. Left and right clicks can't be assigned.

A press of an assigned button goes only to JRectangle, so the app under the pointer doesn't also act on it, for example by going back in a browser. Buttons that aren't assigned work as usual. Like keyboard shortcuts, mouse button shortcuts are off while an ignored app is frontmost or a shortcut is being recorded, and assigning one button to several actions cycles through them.

Mouse button shortcuts act on the focused window, as keyboard shortcuts do. To have them act on the window under the pointer instead, turn on **Mouse button shortcuts act on the window under the pointer** in **Behavior** > **Extras**. Focus stays where it is, except with actions that work by bringing windows forward, such as the cycle actions. When there's no window under the pointer, JRectangle beeps.

If pressing a button doesn't record it, other software, such as your mouse's own utility, may be remapping the button before JRectangle sees it.

### Ignore an app

Ignoring an app means that when the app is frontmost, keyboard shortcuts are un-registered from macOS. When the app is no longer frontmost, keyboard shortcuts are re-registered with macOS. This is useful for apps that have the same shortcuts like JRectangle and you do not want to change them. Double-clicking the title bar of an ignored app's window does not trigger JRectangle's title bar action either.

1. Focus the app that you want to ignore (make a window from that app frontmost).
1. Open the JRectangle menu and select "Ignore app"

To un-ignore an app that you have selected to ignore, simply bring that app frontmost again, open the JRectangle menu, and deselect "Ignore".

## Execute an action by URL

Open the URL `rectangle://execute-action?name=[name]`. Do not activate JRectangle if possible.

Available values for `[name]`: `left-half`, `right-half`, `center-half`, `top-half`, `bottom-half`, `top-left`, `top-right`, `bottom-left`, `bottom-right`, `first-third`, `center-third`, `last-third`, `first-two-thirds`, `last-two-thirds`, `maximize`, `almost-maximize`, `maximize-height`, `smaller`, `larger`, `center`, `center-prominently`, `restore`, `next-display`, `previous-display`, `move-left`, `move-right`, `move-up`, `move-down`, `first-fourth`, `second-fourth`, `third-fourth`, `last-fourth`, `first-three-fourths`, `last-three-fourths`, `top-left-sixth`, `top-center-sixth`, `top-right-sixth`, `bottom-left-sixth`, `bottom-center-sixth`, `bottom-right-sixth`, `specified`, `reverse-all`, `top-left-ninth`, `top-center-ninth`, `top-right-ninth`, `middle-left-ninth`, `middle-center-ninth`, `middle-right-ninth`, `bottom-left-ninth`, `bottom-center-ninth`, `bottom-right-ninth`, `top-left-third`, `top-right-third`, `bottom-left-third`, `bottom-right-third`, `top-left-eighth`, `top-center-left-eighth`, `top-center-right-eighth`, `top-right-eighth`, `bottom-left-eighth`, `bottom-center-left-eighth`, `bottom-center-right-eighth`, `bottom-right-eighth`, `tile-all`, `tile-rows`, `tile-columns`, `cascade-all`, `cascade-active-app`, `cycle-stacked-windows`, `cycle-stacked-windows-backward`

Example, from a shell: `open -g "rectangle://execute-action?name=left-half"`

URLs can also be used to ignore/unignore apps. 

```
rectangle://execute-task?name=ignore-app
rectangle://execute-task?name=unignore-app
```
A bundle identifier can also be specified, for example:
```
rectangle://execute-task?name=ignore-app&app-bundle-id=com.apple.Safari
```

## Terminal Commands for Hidden Preferences

See [TerminalCommands.md](TerminalCommands.md)

## Differences with Spectacle

* JRectangle uses [MASShortcut](https://github.com/rxhanson/MASShortcut) for keyboard shortcut recording. Spectacle used its own shortcut recorder.
* JRectangle has additional window actions: move windows to each edge without resizing, maximize only the height of a window, almost maximizing a window.
* Next/prev screen thirds is replaced with explicitly first third, first two thirds, center third, last two thirds, and last third. Screen orientation is taken into account, as in first third will be left third on landscape and top third on portrait.
  * You can however emulate Spectacle's third cycling using first and last third actions. So, if you repeatedly execute first third, it will cycle through thirds (first, center, last) and vice-versa with the last third.
* There's an option to have windows traverse across displays on repeated side actions. Left/Right Half use the display ordering. Top/Bottom Half move to the nearest display above/below with horizontal overlap, landing on its facing half. At the top or bottom of a display stack, traversal wraps to its opposite end, just like left/right cycling. The combined traverse-and-resize option cycles sizes at the boundary instead.
* Windows will snap when dragged to edges/corners of the screen. This can be disabled.

## Common Known Issues

### Moving windows between desktops is experimental

macOS does not provide a public API for moving another app's window between Spaces. JRectangle's experimental desktop shortcuts simulate a drag and have the limitations described above.

### Windows overlap when using thirds or other small layouts

Some apps enforce a minimum window size that is larger than the requested layout. For example, a window with a minimum width of 600 points cannot fit a 504-point third of a display. JRectangle keeps the window on screen and briefly shows a “Minimum window size reached” HUD with a window icon when the app leaves it larger than the requested size. Use a larger layout, such as halves, or reduce the adjacent window manually. JRectangle cannot override an app's minimum window size.

### Window resizing is off slightly for iTerm2

By default iTerm2 will only resize in increments of character widths. There might be a setting inside iTerm2 to disable this, but you can change it with the following command.

```bash
defaults write com.googlecode.iterm2 DisableWindowSizeSnap -integer 1
```

### JRectangle appears to cause Notification Center to freeze

This appears to affect only a small amount of users. To prevent this from happening, uncheck the box for "Snap windows by dragging".
See issue [317](https://github.com/rxhanson/Rectangle/issues/317).

### Troubleshooting

If windows aren't resizing or moving as you expect, here's some initial steps to get to the bottom of it. Most issues of this type have been caused by other apps.

**Quick fixes (try these first):**

1. **Lock and unlock your Mac** – This simple step resolves many issues, especially after system updates.
1. Make sure macOS is up to date.
1. Restart your Mac (this often fixes things right after a macOS update).

**Diagnose the issue:**

4. **Enable debug logging** (see instructions in the following section) – This helps identify whether JRectangle is working correctly.
1. The logs are straightforward. If your calculated rect and your resulting rect are identical, chances are that there is another application causing issues.

**Check for conflicts:**

6. Make sure there are no other window manager applications running.
1. Make sure that the app whose windows are not behaving properly does not have any conflicting keyboard shortcuts.
1. Try using the menu items to execute a window action or changing the keyboard shortcut to something different so we can tell if it's a keyboard shortcut issue or not.

**Advanced troubleshooting:**

9. If you suspect there may be another application causing issues, try creating and logging in as a new macOS user.
1. Save your logs to attach to an issue if you need to create one.

#### Try resetting the macOS accessibility permissions for JRectangle:

```bash
tccutil reset All com.knollsoft.Rectangle
```

Or, this can be done with the following steps instead of the tccutil terminal command.
1. Close JRectangle if it's running
2. In System Settings -> Privacy & Security -> Accessibility, first disable JRectangle, then remove it with the minus button. (it's important to do both of those steps in that order)
3. Restart your mac.
4. Launch JRectangle and enable settings for it as prompted.

## View Debug Logging

1. Hold down the alt (option) key with the JRectangle menu open.
1. Select the "View Logging..." menu item, which is in place of the "About" menu item.
1. Logging will appear in the window as you perform JRectangle commands.

## Import & export JSON config

There are buttons for importing and exporting the config as a JSON file on the **App Settings** tab of the Settings window.

Upon launch, JRectangle asks whether to apply a config file found at `~/Library/Application Support/Rectangle/RectangleConfig.json`. After applying it, the app renames it with a timestamp so it isn't read on subsequent launches.

## Preferences storage

JRectangle stores its settings and shortcuts in `~/Library/Application Support/JRectangle/config.json`.
On first launch it copies existing app preferences from `com.knollsoft.Rectangle` without deleting them.
Debug builds use `~/Library/Application Support/JRectangle/Debug/config.json` and migrate the separate debug preferences.

Quit JRectangle before editing the file. If JRectangle detects an external change when saving, it warns instead of overwriting it.
Use **Import** and **Export** in App Settings to share settings and shortcuts. Export files use the existing Rectangle import format and are distinct from the live settings file.

macOS manages permissions and launch-at-login separately. JRectangle also reads macOS window manager, Dock and title-bar preferences, and may disable macOS window tiling when resolving conflicts; those system preferences remain in their macOS domains.

## Uninstallation

JRectangle can be uninstalled by quitting the app and moving it to the trash. Its settings file remains in `~/Library/Application Support/JRectangle/`. Old, pre-migration defaults can also be removed with:

```bash
defaults delete com.knollsoft.Rectangle
```

> [!TIP]  
> If you are uninstalling after installing with Homebrew, you should include the `--zap` flag to ensure it removes the plist entries too. 

```
brew uninstall --zap rectangle
```

---

## Contributing

Logic from Rectangle is used in the [Multitouch](https://multitouch.app) app. The [Rectangle Pro](https://rectangleapp.com/pro) app is entirely built on top of Rectangle. If you contribute significant code or localizations that get merged into Rectangle, send me an email for a free license of Multitouch or Rectangle Pro. Contributors to Sparkle, MASShortcut, or Spectacle can also receive free Multitouch or Rectangle Pro licenses.

### Contributing additional sizes and positions

JRectangle's UI is intentionally simple. If you want to add a size and position that's not in the main list of the Shortcuts tab, then you can now add them into the "Extra" section, inside the collapsible "⋯" section at the bottom of the Shortcuts tab.

### Localization

If you would like to contribute to localization, all of the translations are held in the Main.strings.

Pull requests for new localizations or improvements on existing localizations are welcome.

### Build and run from source

You need Xcode and a Mac that can run the app (macOS 14 or later). JRectangle uses Swift Package Manager for MASShortcut; Xcode resolves this dependency when you open the project. Update checks have been removed from this fork.

1. Open `Rectangle.xcodeproj` in Xcode.
1. Select the **Rectangle** scheme and **My Mac** as the run destination.
1. Choose the **Debug** configuration, then press **⌘R** to build and run.
1. Grant JRectangle permission under **System Settings > Privacy & Security > Accessibility** when macOS prompts you.

Debug builds use the separate bundle identifier `com.knollsoft.Rectangle.debug` and ad-hoc signing, so they keep their own preferences and Accessibility permission without needing a developer certificate. Quit any installed copy of JRectangle before running the Debug build; otherwise both copies will respond to the same shortcuts and window drags. After granting permission, enable the Debug build in Accessibility if it is not already enabled. macOS may require you to grant Accessibility permission again after rebuilding or changing the app's path.

You can also build and launch the Debug app from Terminal:

```bash
xcodebuild -project Rectangle.xcodeproj \
  -scheme Rectangle \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  build
open build/Build/Products/Debug/JRectangle.app
```

If an ad-hoc signed rebuild stops responding to shortcuts, remove its old Accessibility entry in System Settings and grant permission again. To clear the entry from Terminal:

```bash
tccutil reset Accessibility com.knollsoft.Rectangle.debug
```

JRectangle uses a J-marked app icon. If asset compilation fails on a Mac running an older macOS version, remove **Asset Catalog Other Flags** from the project build settings locally; do not include that change in a pull request.

## Credits

JRectangle uses a forked version of [MASShortcut](https://github.com/rxhanson/MASShortcut).

The Big Sur variant of the Rectangle app icon was created by Giovanni Maria Cusaro (@gmcusaro). The Liquid Glass variant of the app icon was created by [Alexander Käßner](https://www.alexkaessner.de) (@alexkaessner).

And of course, there's been a lot of community contributions over the years :)
