#!/usr/bin/env bash
# Remove the Minecraft hotbar plugin and put the previous bar back.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
LAYOUTS="$STATE/mchotbar"
PLUGIN_DIR="$OMARCHY_CONFIG/plugins/mchotbar"
PIN_DIR="$OMARCHY_CONFIG/mchotbar"
OTHER="winbar"

say() { printf '%s\n' "$*"; }

# ------------------------------------------------------------ 1. plugin off
say "disabling the plugin"
for i in 1 2 3 4 5; do omarchy plugin disable mchotbar >/dev/null 2>&1 && break; sleep 1; done

# ------------------------------------------------------------- 2. keybind
say "removing the SUPER + E binding"
BINDINGS="$HOME/.config/hypr/bindings.lua"
if [[ -f "$BINDINGS" ]]; then
  python3 - "$BINDINGS" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().split("\n")
out = []
skip = False
for line in lines:
    if line.startswith("-- Minecraft hotbar:"):
        skip = True
        continue
    if skip:
        if line.startswith("o.bind("):
            skip = False
            continue
        if line.strip() == "":
            skip = False
            continue
        skip = False
    out.append(line)
text = "\n".join(out)
# Drop trailing blank runs down to a single newline.
p.write_text(text.rstrip("\n") + "\n")
PY
  hyprctl reload >/dev/null 2>&1 || true
  say "  removed"
fi

# ------------------------------------------------------------- 3. configs
say "restoring the previous bar"
if [[ -f "$STATE/shell.json.mchotbar-bak" ]]; then
  cp "$STATE/shell.json.mchotbar-bak" "$OMARCHY_CONFIG/shell.json"
  say "  shell.json restored from backup"
elif [[ -f "$LAYOUTS/shell.json.$OTHER" ]]; then
  cp "$LAYOUTS/shell.json.$OTHER" "$OMARCHY_CONFIG/shell.json"
  say "  shell.json restored from the $OTHER snapshot"
else
  say "  no backup found; leaving shell.json as-is"
fi

if [[ -f "$STATE/shell.toml.mchotbar-bak" ]]; then
  cp "$STATE/shell.toml.mchotbar-bak" "$OMARCHY_CONFIG/shell.toml"
  say "  shell.toml restored from backup"
elif [[ -f "$LAYOUTS/shell.toml.$OTHER" ]]; then
  cp "$LAYOUTS/shell.toml.$OTHER" "$OMARCHY_CONFIG/shell.toml"
  say "  shell.toml restored from the $OTHER snapshot"
else
  say "  no backup; leaving shell.toml as-is"
fi

if [[ -f "$STATE/bindings.lua.mchotbar-bak" ]]; then
  cp "$STATE/bindings.lua.mchotbar-bak" "$BINDINGS"
  say "  hypr/bindings.lua restored from backup"
fi

# ------------------------------------------------------------- 4. cleanup
if [[ -d "$PLUGIN_DIR" ]]; then
  rm -rf "$PLUGIN_DIR"
  say "removed $PLUGIN_DIR"
fi

say "applying"
for i in 1 2 3 4 5; do omarchy-shell shell reloadConfig >/dev/null 2>&1 && break; sleep 1; done
for i in 1 2 3 4 5; do omarchy restart shell >/dev/null 2>&1 && break; sleep 1; done

cat <<EOF

Removed.

The slot list is still at $PIN_DIR/pins.json if you want it back later.
EOF
