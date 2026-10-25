# omarchy-mchotbar

A Minecraft-style taskbar for [Omarchy](https://omarchy.org): nine item slots
holding your apps, and a Minecraft-styled app search menu on **SUPER + E**.

It is a second bar alongside [`omarchy-winbar`](https://github.com/finleydavid2026-beep/omarchy-winbar),
not a replacement — `switch.sh` flips between the two.

## What you get

| piece | behaviour |
|---|---|
| `mchotbar` | 9 Minecraft slots in the centre of the bar. Click a slot to launch that app. |
| `SUPER + E` | Minecraft-styled menu: a search field plus your apps. Type to filter, ↑/↓ to move, Enter to launch, Esc to close. |
| `omarchy.clock` | kept, moved into the centre group |

The slot styling is the **actual pixel art** from the reference HUD, not a
redrawn approximation — `art/slot.png`, `art/slot_selected.png`,
`art/hearts.png` and `art/food.png` are cropped straight from the source image
and scaled with `smooth: false` so the pixels stay crisp. The health row sits at
the left end of the bar, the hunger row at the right end, and the nine slots
run between them, which is the HUD rearranged onto the one row a taskbar needs.

The bar background is set to black for this layout so the art's own black
background blends into the bar with no seam.

### Hearts = battery, armour = wifi

The two icon strips are live:

| strip | shows | range |
|---|---|---|
| hearts (left) | battery percentage | 0-100% -> 0-10 hearts |
| armour (right) | wifi signal strength | 0-100 -> 0-10 chestplates |

A full row is ten icons; the count follows the value and the unused ones stay
at low opacity so the row keeps its width instead of jumping around. Battery
comes from `/sys/class/power_supply/BAT0/capacity` and wifi from
`nmcli -t -f ACTIVE,SIGNAL dev wifi`, polled every 5 seconds.

## Install

```bash
git clone https://github.com/finleydavid2026-beep/omarchy-mchotbar.git
cd omarchy-mchotbar
./install.sh
```

The slot list is seeded from your Omarchy hotbar's pins, so the apps you
already pinned are in the slots on the first run. Edit it any time:

```bash
nano ~/.config/omarchy/mchotbar/pins.json
```

It is a plain array of desktop ids — `["chromium", "steam", "localsend"]`. A
`class:org.foo.Bar` pin is resolved back to a desktop id by matching a dotted
segment, so `class:org.localsend.localsend_app` finds `localsend`.

## The pixel font (optional but recommended)

The menu and slot labels use **Monocraft**, a Minecraft-style pixel font with
Nerd Font glyphs. The bar works without it (Qt falls back to the system font),
but it will not look like Minecraft.

```bash
cd ~/.cache/yay/ttf-monocraft-nerd
sudo pacman -U ttf-monocraft-nerd-4.2.1-1-any.pkg.tar.zst
```

## Switching bars

```bash
./switch.sh winbar     # back to the Windows-style taskbar
./switch.sh mchotbar   # the Minecraft hotbar
```

Each bar's layout is snapshotted the first time it runs, so switching back
restores what was actually running rather than a hardcoded default.

## Uninstall

```bash
./uninstall.sh
```

Restores `shell.json`, `shell.toml` and `hypr/bindings.lua` from the backups
taken at install time, removes the `SUPER + E` binding and deletes the plugin.
Your slot list at `~/.config/omarchy/mchotbar/pins.json` is left in place.

## Files

| file | role |
|---|---|
| `manifest.json` | declares plugin id `mchotbar`, kinds `menu` + `bar-widget` |
| `Hotbar.qml` | the 9-slot hotbar widget |
| `McSlot.qml` | one slot (own file — see below) |
| `Menu.qml` | the Minecraft app search panel |
| `McRow.qml` | one result row |
| `install.sh` / `uninstall.sh` / `switch.sh` | install, undo, switch |

## Notes for anyone extending this

Two things cost real debugging time and are worth knowing:

- **A plugin's menu entry point does not get `shell.appLibrary`.** The shell
  only hands that capability to first-party menu plugins, so a third-party menu
  gets `null` even with `"kinds": ["menu"]` in its manifest. Use Quickshell's
  global `DesktopEntries` singleton instead — `DesktopEntries.applications.values`
  gives the same entries (`.id`, `.name`, `.icon`, `.keywords`, `.noDisplay`,
  `.execute()`).
- **A Repeater delegate cannot use an inline `component` declared in the parent
  file.** The model context (`modelData`) does not reach the delegate body, so
  the cell has to live in its own `.qml` file. `McSlot.qml` and `McRow.qml`
  exist for exactly this reason.
