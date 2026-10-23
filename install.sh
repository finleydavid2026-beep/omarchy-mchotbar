#!/usr/bin/env bash
# Install the Minecraft hotbar plugin.
#
# Everything the Windows-style taskbar needs is restored by uninstall.sh or by
# switch.sh winbar, so this is safe to run on a machine that already has the
# other bar installed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
PLUGIN_DIR="$OMARCHY_CONFIG/plugins/mchotbar"
PIN_DIR="$OMARCHY_CONFIG/mchotbar"
LAYOUTS="$STATE/mchotbar"
SELF="mchotbar"
OTHER="winbar"

DRY_RUN=0
NO_FONT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-font) NO_FONT=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in omarchy omarchy-shell; do
  command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' not found — is Omarchy installed?"
done

mkdir -p "$STATE" "$LAYOUTS" "$PIN_DIR"

# ---------------------------------------------------------------- 1. back up
# Take the backups before anything touches the config. `omarchy plugin enable`
# writes the widget into shell.json, so a backup taken afterwards would already
# contain this plugin's own changes and could not be undone.
if (( !DRY_RUN )); then
  for f in shell.json shell.toml; do
    if [[ -f "$OMARCHY_CONFIG/$f" && ! -f "$STATE/$f.mchotbar-bak" ]]; then
      cp "$OMARCHY_CONFIG/$f" "$STATE/$f.mchotbar-bak"
      say "backed up $f to $STATE/$f.mchotbar-bak"
    fi
  done
  if [[ -f "$HOME/.config/hypr/bindings.lua" && ! -f "$STATE/bindings.lua.mchotbar-bak" ]]; then
    cp "$HOME/.config/hypr/bindings.lua" "$STATE/bindings.lua.mchotbar-bak"
    say "backed up hypr/bindings.lua"
  fi
fi

# ------------------------------------------------------- 2. keep the old bar
# Snapshot the bar this machine is currently running so switch.sh winbar can
# bring it back. Only the first snapshot is kept, so switching back always
# restores the original rather than the last thing switched to.
if (( !DRY_RUN )); then
  for f in shell.json shell.toml; do
    if [[ -f "$OMARCHY_CONFIG/$f" && ! -f "$LAYOUTS/$f.$OTHER" ]]; then
      cp "$OMARCHY_CONFIG/$f" "$LAYOUTS/$f.$OTHER"
      say "snapshotted the current bar as $f.$OTHER"
    fi
  done
fi

# ---------------------------------------------------------------- 3. plugin
say "installing plugin"
if (( DRY_RUN )); then
  say "  would copy the plugin to $PLUGIN_DIR"
else
  mkdir -p "$PLUGIN_DIR"
  cp "$REPO/manifest.json" "$PLUGIN_DIR/"
  cp "$REPO/Hotbar.qml" "$PLUGIN_DIR/"
  cp "$REPO/McSlot.qml" "$PLUGIN_DIR/"
  cp "$REPO/Menu.qml" "$PLUGIN_DIR/"
  cp "$REPO/McRow.qml" "$PLUGIN_DIR/"
fi

# ------------------------------------------------------------- 4. app slots
# Seed the slot list from the Omarchy hotbar's pins so the apps you already
# pinned are in the slots from the first run.
if (( !DRY_RUN )) && [[ ! -f "$PIN_DIR/pins.json" ]]; then
  if command -v hotbar >/dev/null 2>&1 && hotbar state >/dev/null 2>&1; then
    if hotbar state 2>/dev/null | python3 -c "
import json, sys
pins = json.load(sys.stdin).get('pins', [])
json.dump(pins, open('$PIN_DIR/pins.json', 'w'), indent=2)
print()
" >/dev/null 2>&1; then
      say "seeded slots from the Omarchy hotbar pins"
    fi
  fi
  if [[ ! -f "$PIN_DIR/pins.json" ]]; then
    printf '[]\n' > "$PIN_DIR/pins.json"
    say "no hotbar pins found; wrote an empty slot list"
  fi
fi

# ------------------------------------------------------------ 5. bar layout
say "writing the Minecraft bar layout"
if (( !DRY_RUN )); then
  python3 - "$OMARCHY_CONFIG/shell.json" "$LAYOUTS/shell.json.$SELF" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])

cfg = json.loads(path.read_text())
bar = cfg.setdefault("bar", {})
layout = bar.setdefault("layout", {})

# The Minecraft hotbar replaces the Windows start button, search pill and
# dock; the clock stays and moves into the centre group.
left = [e for e in layout.get("left", []) if isinstance(e, dict) and e.get("id") in ("omarchy.workspaces", "omarchy.agents")]
right = [e for e in layout.get("right", []) if isinstance(e, dict) and not e.get("id", "").startswith("win")]
right = [e for e in right if e.get("id") not in ("theclaw.network", "theclaw.audio", "theclaw.power")]

center = [{"id": "mchotbar"}, {"id": "omarchy.clock"}]
layout["left"] = left
layout["right"] = right
layout["center"] = center
bar["centerAnchor"] = ""
bar["transparent"] = False

path.write_text(json.dumps(cfg, indent=2) + "\n")
out.write_text(json.dumps(cfg, indent=2) + "\n")
print("  centre: " + ", ".join(e["id"] for e in center))
PY

  # The hotbar slots are 44px with padding, so the bar has to be taller than the
  # Windows bar's 42px or the slots get clipped at the top and bottom.
  python3 - "$OMARCHY_CONFIG/shell.toml" "$LAYOUTS/shell.toml.$SELF" <<'PY'
import sys, pathlib

path = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
text = path.read_text() if path.exists() else ""

block = """
# Minecraft hotbar: 44px slots plus padding needs a taller bar than the
# Windows-style taskbar's 42px, or the slots clip.
[bar]
background = "#232323"
background-alpha = 1.0
size-horizontal = 56
size-vertical = 60
icon-slot = 40
icon-canvas = 30
icon-font = 20
status-slot = 32
"""

# Replace an existing [bar] section, or append one.
lines = text.split("\n")
start = next((i for i, l in enumerate(lines) if l.strip() == "[bar]"), None)
if start is None:
    text = text.rstrip("\n") + "\n" + block
else:
    end = start + 1
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    text = "\n".join(lines[:start]) + "\n" + block + "\n".join(lines[end:])

path.write_text(text)
out.write_text(text)
print("  bar height: 56px")
PY

  # ------------------------------------------------------------ 6. keybind
  BINDINGS="$HOME/.config/hypr/bindings.lua"
  if [[ -f "$BINDINGS" ]]; then
    if ! grep -q "Minecraft menu" "$BINDINGS"; then
      printf '\n-- Minecraft hotbar: SUPER + E opens the Minecraft app search menu.\no.bind("SUPER + E", "Minecraft menu", "omarchy-shell shell toggle mchotbar \x27{}\x27")\n' >> "$BINDINGS"
      say "added the SUPER + E binding"
    else
      say "SUPER + E binding already present"
    fi
  fi

  # ------------------------------------------------------------- 7. enable
  for i in 1 2 3 4 5; do omarchy plugin enable mchotbar >/dev/null 2>&1 && break; sleep 1; done
  for i in 1 2 3 4 5; do omarchy-shell shell reloadConfig >/dev/null 2>&1 && break; sleep 1; done
  for i in 1 2 3 4 5; do omarchy restart shell >/dev/null 2>&1 && break; sleep 1; done
fi

cat <<EOF

Done. The Minecraft hotbar is live.

  hotbar      mchotbar            9 slots, click to launch an app
  menu        SUPER + E           search and launch apps

Change the slot contents:
  nano ~/.config/omarchy/mchotbar/pins.json

Switch back to the Windows taskbar:
  $REPO/switch.sh winbar

Undo completely:
  $REPO/uninstall.sh
EOF
