#!/usr/bin/env bash
# Switch between the two taskbars.
#
#   switch.sh winbar     Windows-style taskbar (start button, search pill, dock)
#   switch.sh mchotbar   Minecraft hotbar (9 slots) + SUPER + E app search
#
# Each bar's layout is snapshotted the first time it is installed, so switching
# is just a copy back — no re-derivation, and switching back always restores
# what was actually running rather than a hardcoded default.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
LAYOUTS="$STATE/mchotbar"
SELF="mchotbar"
OTHER="winbar"

target="${1:-}"
case "$target" in
  winbar|mchotbar) ;;
  "") echo "usage: $(basename "$0") <winbar|mchotbar>" >&2; exit 2 ;;
  *) echo "unknown bar: $target (expected winbar or mchotbar)" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*"; }

# 1. Snapshot whatever is running right now under the *other* name, so the
#    target can be restored later. Only the first snapshot of each bar is kept.
if [[ -f "$OMARCHY_CONFIG/shell.json" ]]; then
  if [[ ! -f "$LAYOUTS/shell.json.$OTHER" ]]; then
    cp "$OMARCHY_CONFIG/shell.json" "$LAYOUTS/shell.json.$OTHER"
    say "snapshotted the running bar as $OTHER"
  fi
  if [[ ! -f "$LAYOUTS/shell.toml.$OTHER" ]]; then
    cp "$OMARCHY_CONFIG/shell.toml" "$LAYOUTS/shell.toml.$OTHER"
  fi
fi

# 2. Apply the target.
if [[ ! -f "$LAYOUTS/shell.json.$target" ]]; then
  say "no stored layout for $target — installing it instead"
  exec "$REPO/install.sh"
fi

cp "$LAYOUTS/shell.json.$target" "$OMARCHY_CONFIG/shell.json"
cp "$LAYOUTS/shell.toml.$target" "$OMARCHY_CONFIG/shell.toml"
say "applied the $target layout"

# 3. Enable the matching plugin and disable the other, so only one is live.
if [[ "$target" == "mchotbar" ]]; then
  for i in 1 2 3 4 5; do omarchy plugin enable mchotbar >/dev/null 2>&1 && break; sleep 1; done
  for i in 1 2 3 4 5; do omarchy plugin disable winbar >/dev/null 2>&1 && break; sleep 1; done
else
  for i in 1 2 3 4 5; do omarchy plugin enable winbar >/dev/null 2>&1 && break; sleep 1; done
  for i in 1 2 3 4 5; do omarchy plugin disable mchotbar >/dev/null 2>&1 && break; sleep 1; done
fi

for i in 1 2 3 4 5; do omarchy-shell shell reloadConfig >/dev/null 2>&1 && break; sleep 1; done
for i in 1 2 3 4 5; do omarchy restart shell >/dev/null 2>&1 && break; sleep 1; done

say "switched to $target"
