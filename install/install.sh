#!/usr/bin/env bash
# install.sh - v1.0.0
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026
# SDDM theme by Darkkal44 / Qylock, Serpantinum by ilyamiro.
set -euo pipefail

VERSION="1.0.0"
USER_NAME="${USER:-rop}"
HOME_DIR="${HOME:-/home/$USER_NAME}"
SCRIPTS_DIR="$HOME_DIR/scripts"
SERVICE_DIR="$HOME_DIR/.config/systemd/user"
THEME_DIR="/usr/share/sddm/themes/material-you"
PALETTE="$HOME_DIR/.local/state/serpantinum/qs_matugen_colors.json"
LOG_DIR="$HOME_DIR/.local/state/sddm-sync"
LOG_FILE="$LOG_DIR/install.log"

YES=0; DO_UNINSTALL=0; DO_CHECK=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --uninstall) DO_UNINSTALL=1 ;;
    --check) DO_CHECK=1 ;;
    --version) echo "install.sh $VERSION"; exit 0 ;;
    --help|-h) echo "Usage: bash install/install.sh [--yes] [--uninstall] [--check] [--version]"; echo "  --yes        skip the confirm prompt"; echo "  --uninstall  remove watcher + service + sudoers rule, restore original theme"; echo "  --check      verify install only, change nothing"; echo "  --version    print version and exit"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
  esac
done

# Arch / CachyOS only.
if [ ! -f /etc/arch-release ] && ! command -v pacman >/dev/null 2>&1; then
  echo "ERROR: this installer supports Arch Linux / CachyOS (pacman) only."
  echo "You are not on Arch. Install the requirements manually (matugen, ffmpeg, python3, inotify-tools, git), then copy sddm-sync.sh + sddm-watch.sh by hand."
  exit 1
fi

log() { echo "[$(date '+%H:%M:%S')] $*"; }
mkdir -p "$LOG_DIR"
# Log to install.log
exec > >(tee -a "$LOG_FILE") 2>&1

# Uninstall
if [ "$DO_UNINSTALL" -eq 1 ]; then
  echo "== Uninstalling SDDM sync v$VERSION =="
  systemctl --user disable --now sddm-sync-watcher.service 2>/dev/null || true
  rm -f "$SERVICE_DIR/sddm-sync-watcher.service"
  systemctl --user daemon-reload 2>/dev/null || true
  sudo rm -f /etc/sudoers.d/sddm-sync 2>/dev/null || true
  # Restore the original theme
  if [ -f "$THEME_DIR/Main.qml.orig" ]; then
    sudo cp "$THEME_DIR/Main.qml.orig" "$THEME_DIR/Main.qml"
    sudo rm -f "$THEME_DIR/Main.qml.orig"
    echo "Restored original Main.qml from Main.qml.orig"
  elif [ -f "$THEME_DIR/Main.qml.bak" ]; then
    sudo cp "$THEME_DIR/Main.qml.bak" "$THEME_DIR/Main.qml"
    echo "Restored original Main.qml from Main.qml.bak"
  else
    echo "NOTE: no Main.qml backup found - theme colours stay as they are."
  fi
  if [ -f "$THEME_DIR/bg_dark.jpg.bak" ]; then
    sudo cp "$THEME_DIR/bg_dark.jpg.bak" "$THEME_DIR/bg_dark.jpg"
    sudo cp "$THEME_DIR/bg_dark.jpg.bak" "$THEME_DIR/bg.jpg"
    echo "Restored original SDDM background."
  fi
  sudo chmod 644 "$THEME_DIR/Main.qml" "$THEME_DIR/bg_dark.jpg" "$THEME_DIR/bg.jpg" 2>/dev/null || true
  # Delete the scripts and backups we made.
  rm -f "$SCRIPTS_DIR/sddm-sync.sh" "$SCRIPTS_DIR/sddm-watch.sh"
  rm -f "$SCRIPTS_DIR/sddm-sync.sh.bak" "$SCRIPTS_DIR/sddm-watch.sh.bak"
  rm -f "$HOME_DIR/.local/bin/sddm-sync"
  sudo rm -f "$THEME_DIR/Main.qml.bak" "$THEME_DIR/bg_dark.jpg.bak" 2>/dev/null || true
  rm -rf "$LOG_DIR"
  # Delete the stored installer copy last.
  rm -rf "${XDG_CACHE_HOME:-$HOME_DIR/.cache}/sddm-serpantinum-sync"
  echo "Done. SDDM is back to its original theme - nothing left behind."
  exit 0
fi

# Check only
check_one() { command -v "$1" >/dev/null 2>&1 && echo "OK   $1" || echo "MISS $1 ($2)"; }
if [ "$DO_CHECK" -eq 1 ]; then
  echo "== Check (no changes) =="
  check_one serpantinum "Serpantinum - required, install it first"
  check_one matugen "pacman: matugen"
  check_one ffmpeg "pacman: ffmpeg"
  check_one python3 "pacman: python"
  check_one inotifywait "pacman: inotify-tools"
  check_one git "pacman: git"
  [ -d "$THEME_DIR" ] && echo "OK   theme $THEME_DIR" || echo "MISS theme $THEME_DIR (auto-downloaded on install)"
  [ -f "$PALETTE" ] && echo "OK   palette $PALETTE" || echo "MISS palette (appears after first wallpaper change)"
  systemctl --user is-active --quiet sddm-sync-watcher.service && echo "OK   watcher running" || echo "MISS watcher not running"
  [ -f /etc/sudoers.d/sddm-sync ] && echo "OK   sudoers rule" || echo "MISS sudoers rule"
  ls -l --time-style=+%H:%M "$THEME_DIR/bg_dark.jpg" 2>/dev/null || true
  exit 0
fi

echo "== SDDM sync installer v$VERSION - user $USER_NAME =="
if [ "$YES" -eq 0 ]; then
  # Read from /dev/tty when piped, so the prompt still works.
  if [ -t 0 ]; then
    read -r -p "Do you want to install SDDM Serpantinum theme sync? [y/N] " answer
  elif [ -r /dev/tty ]; then
    read -r -p "Do you want to install SDDM Serpantinum theme sync? [y/N] " answer < /dev/tty
  else
    echo "No terminal available for the confirm prompt - re-run with --yes."
    exit 0
  fi
  case "$answer" in y|Y|yes|YES) echo "Installing..." ;; *) echo "Cancelled. Nothing was changed."; exit 0 ;; esac
fi

# Requirements
ensure_pkg() {
  local cmd="$1" pkg="$2" aur_pkg="${3:-$2}"
  if command -v "$cmd" >/dev/null 2>&1; then log "OK: $cmd"; return 0; fi
  log "Missing: $cmd - installing $pkg..."
  if sudo pacman -Sy --noconfirm --needed "$pkg" 2>/dev/null; then
    command -v "$cmd" >/dev/null 2>&1 && return 0
  fi
  if command -v paru >/dev/null 2>&1; then
    paru -S --noconfirm --needed "$aur_pkg" && return 0
  elif command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm --needed "$aur_pkg" && return 0
  else
    log "No AUR helper - cloning AUR package $aur_pkg via git..."
    local tmp; tmp="$(mktemp -d)"
    git clone "https://aur.archlinux.org/$aur_pkg.git" "$tmp/$aur_pkg" && (cd "$tmp/$aur_pkg" && makepkg -si --noconfirm)
    local rc=$?; rm -rf "$tmp"; [ "$rc" -eq 0 ] && return 0
  fi
  echo "ERROR: could not install $pkg ($cmd still missing)."; exit 1
}

# git first, the self-update below needs it
ensure_pkg git git
# Self-update: if this installer lives in a git repo, pull the latest version first
if [ -d "$(dirname "$0")/.git" ]; then
  log "Updating installer from git..."
  git -C "$(dirname "$0")" pull --ff-only || log "NOTE: git pull failed - continuing with the local copy."
fi
# Keep a copy of this installer, so uninstall works without the Downloads folder.
SHARE_DIR="${XDG_CACHE_HOME:-$HOME_DIR/.cache}/sddm-serpantinum-sync"
mkdir -p "$SHARE_DIR"
# Only copy when $0 is a real file. Piped installs skip it.
if [ -f "$0" ]; then
  cp "$0" "$SHARE_DIR/install.sh"
  chmod +x "$SHARE_DIR/install.sh"
  log "Stored installer copy at $SHARE_DIR/install.sh"
else
  log "NOTE: piped install ($0 is not a file) - skipping stored copy. To uninstall later, re-download the installer."
fi

ensure_pkg python3 python
ensure_pkg ffmpeg ffmpeg
ensure_pkg matugen matugen
ensure_pkg inotifywait inotify-tools

# Serpantinum is required, this installer does not install it.
command -v serpantinum >/dev/null 2>&1 || { echo "ERROR: 'serpantinum' not found. This sync is for Serpantinum users - install Serpantinum first (curl -fsSL install.serpantinum.dev | bash), then re-run."; exit 1; }

# Theme missing, download it
if [ ! -d "$THEME_DIR" ]; then
  log "Theme missing - downloading automatically from Darkkal44/qylock..."
  QYLOCK_TMP="$(mktemp -d)"
  git clone --depth 1 https://github.com/Darkkal44/qylock.git "$QYLOCK_TMP/qylock"
  THEME_SRC="$(find "$QYLOCK_TMP/qylock/themes" -maxdepth 2 -type d -iname "*material-you*" -print -quit)"
  [ -n "$THEME_SRC" ] || { rm -rf "$QYLOCK_TMP"; echo "ERROR: material-you theme not found in qylock repo."; exit 1; }
  sudo mkdir -p "$THEME_DIR"
  sudo cp -r "$THEME_SRC"/. "$THEME_DIR"/
  sudo chmod -R a+r "$THEME_DIR"
  sudo mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=material-you\nThemeDir=/usr/share/sddm/themes\n' | sudo tee /etc/sddm.conf.d/serpantinum-theme.conf >/dev/null
  log "Theme installed."
fi
[ -f "$PALETTE" ] || log "NOTE: palette file not found yet - it appears after first wallpaper change."

mkdir -p "$SCRIPTS_DIR" "$SERVICE_DIR" "$LOG_DIR"

# Backups - keep the untouched theme file, patch from that every time.
if [ ! -f "$THEME_DIR/Main.qml.orig" ]; then
  if [ -f "$THEME_DIR/Main.qml.bak" ]; then
    log "Using existing Main.qml.bak as pristine template..."
    sudo cp "$THEME_DIR/Main.qml.bak" "$THEME_DIR/Main.qml.orig"
  else
    log "Saving pristine Main.qml.orig..."
    sudo cp "$THEME_DIR/Main.qml" "$THEME_DIR/Main.qml.orig"
    sudo cp "$THEME_DIR/Main.qml" "$THEME_DIR/Main.qml.bak"
  fi
fi
[ -f "$THEME_DIR/bg_dark.jpg.bak" ] || sudo cp "$THEME_DIR/bg_dark.jpg" "$THEME_DIR/bg_dark.jpg.bak" 2>/dev/null || true
[ -f "$SCRIPTS_DIR/sddm-sync.sh" ] && cp "$SCRIPTS_DIR/sddm-sync.sh" "$SCRIPTS_DIR/sddm-sync.sh.bak"
[ -f "$SCRIPTS_DIR/sddm-watch.sh" ] && cp "$SCRIPTS_DIR/sddm-watch.sh" "$SCRIPTS_DIR/sddm-watch.sh.bak"

# sddm-sync.sh
cat > "$SCRIPTS_DIR/sddm-sync.sh" << 'EOF'
#!/usr/bin/env bash
# SDDM sync - dark from the Serpantinum palette, light from its accent
# Usage: bash ~/scripts/sddm-sync.sh [--force] [--dry-run]
set -euo pipefail
THEME_DIR="/usr/share/sddm/themes/material-you"
PALETTE="$HOME/.local/state/serpantinum/qs_matugen_colors.json"
LOG_DIR="$HOME/.local/state/sddm-sync"
LOG_FILE="$LOG_DIR/sync.log"
LOCK_FILE="$LOG_DIR/sync.lock"
FORCE=0; DRY_RUN=0
for arg in "$@"; do case "$arg" in --force) FORCE=1 ;; --dry-run) DRY_RUN=1 ;; esac; done

mkdir -p "$LOG_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "$(date '+%H:%M:%S') sync already running, skipping" >> "$LOG_FILE"; exit 0; }
log() {
  # Rotate the log if it passes 1 MB, keep the last 500 lines.
  if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -gt 1048576 ]; then
    tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [log] rotated sync.log (was over 1 MB, kept last 500 lines)" >> "$LOG_FILE"
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE";
}
trap 'log "ERROR: sync failed at line $LINENO"' ERR

# Skip if nothing changed, unless --force
STATE_FILE="$LOG_DIR/last-state"
WALLPAPER="$(serpantinum info wallpaper)"
[ -n "$WALLPAPER" ] || { log "ERROR: serpantinum info wallpaper returned empty"; exit 1; }
[ -f "$WALLPAPER" ] || { log "ERROR: wallpaper file not found: $WALLPAPER"; exit 1; }
CURRENT_STATE="$WALLPAPER|$(sha256sum "$PALETTE" 2>/dev/null | cut -d' ' -f1)"
if [ "$FORCE" -eq 0 ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$CURRENT_STATE" ]; then
  log "Wallpaper + palette unchanged - skipping (use --force to re-sync)"
  exit 0
fi

# Private temp dir, not /tmp
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT
TMP_BG="$TMPDIR_WORK/sddm-bg.jpg"
TMP_QML="$TMPDIR_WORK/Main.qml"
TMP_JSON="$TMPDIR_WORK/matugen.json"
SRC_QML="$THEME_DIR/Main.qml.orig"
[ -f "$SRC_QML" ] || SRC_QML="$THEME_DIR/Main.qml"

# Background - frame 10 for video, copy for image
case "$WALLPAPER" in
  *.mp4|*.webm|*.mkv|*.mov)
    ffmpeg -y -loglevel error -i "$WALLPAPER" -vf "select=eq(n\,10)" -vframes 1 "$TMP_BG" ;;
  *) cp "$WALLPAPER" "$TMP_BG" ;;
esac

# Light palette from the accent
ACCENT="$(python3 -c "import json; print(json.load(open('$PALETTE'))['mauve'])")"
matugen color hex "$ACCENT" --mode dark --json hex --dry-run > "$TMP_JSON"

# Patch both sides, from the untouched file
python3 - "$PALETTE" "$TMP_JSON" "$SRC_QML" "$TMP_QML" << 'PYEOF'
import json, sys, re
p = json.load(open(sys.argv[1]))
m = json.load(open(sys.argv[2]))['colors']
qml = open(sys.argv[3]).read()
def rgba(hexcol, alpha):
    h = hexcol.lstrip('#'); r,g,b = (int(h[i:i+2],16)/255 for i in (0,2,4))
    return f"Qt.rgba({r:.3f}, {g:.3f}, {b:.3f}, {alpha})"
def light(role): return m[role]['light']['color']
dark = {'cText': p['text'], 'cDark': p['mauve'], 'cMid': p['green'],
  'cSurfaceHover': p['surface1'], 'cField': p['surface1'],
  'cFieldBox': p['surface2'], 'cSurfaceSolid': p['mantle'],
  'cOnAccent': p['crust'], 'cRed': p['red'], 'cBusy': p['mauve'],
  'cMenu1': p['green'], 'cMenu2': p['mauve'], 'cMenuDanger': p['red']}
light_map = {'cText': 'on_surface', 'cDark': 'primary', 'cMid': 'secondary',
  'cSurfaceHover': 'surface_container_high', 'cField': 'surface_container_high',
  'cFieldBox': 'surface_container_highest', 'cSurfaceSolid': 'surface',
  'cOnAccent': 'on_primary', 'cRed': 'error', 'cBusy': 'primary',
  'cMenu1': 'secondary', 'cMenu2': 'primary', 'cMenuDanger': 'error'}
failed = []
for key, dval in dark.items():
    lval = light(light_map[key])
    new, n = re.subn(rf'({key}:\s*isDark \?\s*")[^"]+"\s*:\s*"[^"]+(")',
                     rf'\g<1>{dval}" : "{lval}\g<2>', qml, count=1)
    if n == 0:
        failed.append(key)
    qml = new
for label, pat, rep in [
    ("cSurface-dark",  r'(cSurface:\s*isDark \?\s*)Qt\.rgba\([^)]+\)', rgba(p["surface0"],0.9)),
    ("cSurface-light", r'(cSurface:\s*isDark \?\s*Qt\.rgba\([^)]+\)\s*:\s*)Qt\.rgba\([^)]+\)', rgba(light("surface_container"),0.92)),
]:
    new, n = re.subn(pat, rf'\g<1>{rep}', qml, count=1)
    if n == 0: failed.append(label)
    qml = new
# Clock digits use the accent
old_clock = 'readonly property color tint: (row + col) % 2 === 0 ? root.cText : root.cMid'
new_clock = 'readonly property color tint: (row + col) % 2 === 0 ? root.cText : root.cDark'
if old_clock in qml:
    qml = qml.replace(old_clock, new_clock)
else:
    failed.append("clock-line-561")
if failed:
    print("FAILED to patch (theme file changed format?): " + ", ".join(failed), file=sys.stderr)
    sys.exit(2)
open(sys.argv[4],'w').write(qml)
print(f"dark cDark={dark['cDark']} light cDark={light('primary')}")
PYEOF

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN - patched QML would be installed, stopping here: $TMP_QML"
  cp "$TMP_QML" "$LOG_DIR/Main.qml.preview"
  exit 0
fi

# Install
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sddm-sync"
mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
cp "$TMP_BG" "$RUNTIME_DIR/sddm-bg.jpg"
cp "$TMP_QML" "$RUNTIME_DIR/Main.qml"
sudo cp "$RUNTIME_DIR/sddm-bg.jpg" "$THEME_DIR/bg_dark.jpg"
sudo cp "$RUNTIME_DIR/sddm-bg.jpg" "$THEME_DIR/bg.jpg"
sudo cp "$RUNTIME_DIR/Main.qml" "$THEME_DIR/Main.qml"
sudo chmod 644 "$THEME_DIR/bg_dark.jpg" "$THEME_DIR/bg.jpg" "$THEME_DIR/Main.qml"
# Check the install worked
[ -s "$THEME_DIR/bg_dark.jpg" ] || { log "ERROR: bg_dark.jpg is empty after install"; exit 1; }
grep -q "$ACCENT" "$THEME_DIR/Main.qml" 2>/dev/null || log "WARNING: new accent $ACCENT not found in installed Main.qml - check $LOG_FILE"
echo "$CURRENT_STATE" > "$STATE_FILE"
log "SDDM synced (dark+light): $WALLPAPER"
EOF
chmod +x "$SCRIPTS_DIR/sddm-sync.sh"
log "Wrote $SCRIPTS_DIR/sddm-sync.sh (v1.0.0)"

# sddm-watch.sh
cat > "$SCRIPTS_DIR/sddm-watch.sh" << 'EOF'
#!/usr/bin/env bash
# Watch the palette file, sync when it changes.
PALETTE="$HOME/.local/state/serpantinum/qs_matugen_colors.json"
PALETTE_DIR="$(dirname "$PALETTE")"
LOG_FILE="$HOME/.local/state/sddm-sync/sync.log"
mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [watch] $*" >> "$LOG_FILE"; }

log "watcher started (pid $$), syncing once on login..."
bash "$HOME/scripts/sddm-sync.sh" --force >> "$LOG_FILE" 2>&1 || log "initial sync failed, will retry on next change"

inotifywait -m -q -e close_write,moved_to,create --format '%e %f' "$PALETTE_DIR" 2>>"$LOG_FILE" | while read -r EVENT; do
  case "$EVENT" in
    *qs_matugen_colors.json*) ;;
    *) continue ;;
  esac
  # Wait until no palette event arrives for 2 seconds, then sync once.
  while read -t 2 -r _EXTRA; do
    case "$_EXTRA" in *qs_matugen_colors.json*) continue ;; *) continue ;; esac
  done
  bash "$HOME/scripts/sddm-sync.sh" >> "$LOG_FILE" 2>&1 || log "sync failed after wallpaper change (see above)"
done
EOF
chmod +x "$SCRIPTS_DIR/sddm-watch.sh"
log "Wrote $SCRIPTS_DIR/sddm-watch.sh (v1.0.0)"

# systemd service
cat > "$SERVICE_DIR/sddm-sync-watcher.service" << EOF
[Unit]
Description=Auto-sync SDDM theme on wallpaper change (inotify)
After=graphical-session.target

[Service]
Environment=PATH=$HOME_DIR/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/bash $HOME_DIR/scripts/sddm-watch.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
log "Wrote $SERVICE_DIR/sddm-sync-watcher.service"

# sddm-sync command
mkdir -p "$HOME_DIR/.local/bin"
cat > "$HOME_DIR/.local/bin/sddm-sync" << 'EOF'
#!/usr/bin/env bash
# sddm-sync - sync, check, log, status, version, uninstall
set -euo pipefail
SCRIPTS_DIR="$HOME/scripts"
LOG_FILE="$HOME/.local/state/sddm-sync/sync.log"
case "${1:-help}" in
  sync) bash "$SCRIPTS_DIR/sddm-sync.sh" --force ;;
  check) bash "$SCRIPTS_DIR/sddm-sync.sh" --check 2>/dev/null || systemctl --user is-active --quiet sddm-sync-watcher.service && echo "OK   watcher running" || echo "MISS watcher not running"; ls -l /usr/share/sddm/themes/material-you/bg_dark.jpg 2>/dev/null || true ;;
  log) tail -f "$LOG_FILE" ;;
  status) systemctl --user status sddm-sync-watcher.service --no-pager ;;
  version) echo "sddm-sync 1.0.0" ;;
  uninstall)
    # Run the stored installer copy.
    if [ -f "${XDG_CACHE_HOME:-$HOME/.cache}/sddm-serpantinum-sync/install.sh" ]; then
      bash "${XDG_CACHE_HOME:-$HOME/.cache}/sddm-serpantinum-sync/install.sh" --uninstall
    else
      echo "Stored installer not found. Re-download it:"
      echo "  curl -fsSL https://raw.githubusercontent.com/NatDev3/sddm-serpantinum-sync/main/install/install.sh -o /tmp/install.sh"
      echo "  bash /tmp/install.sh --uninstall"
    fi
    ;;
  *) echo "Usage: sddm-sync {sync|check|log|status|version|uninstall}" ;;
esac
EOF
chmod +x "$HOME_DIR/.local/bin/sddm-sync"
log "Wrote $HOME_DIR/.local/bin/sddm-sync (v1.0.0)"

# Sudoers rule - only the copy commands, from the private runtime dir
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sddm-sync"
SUDOERS_FILE="/etc/sudoers.d/sddm-sync"
SUDOERS_LINE="$USER_NAME ALL=(ALL) NOPASSWD: /usr/bin/cp $RUNTIME_DIR/sddm-bg.jpg $THEME_DIR/bg_dark.jpg, /usr/bin/cp $RUNTIME_DIR/sddm-bg.jpg $THEME_DIR/bg.jpg, /usr/bin/cp $RUNTIME_DIR/Main.qml $THEME_DIR/Main.qml, /usr/bin/chmod 644 $THEME_DIR/bg_dark.jpg $THEME_DIR/bg.jpg $THEME_DIR/Main.qml"
if [ -f "$SUDOERS_FILE" ] && grep -qxF "$SUDOERS_LINE" "$SUDOERS_FILE"; then
  log "Sudoers rule already present."
else
  log "Installing sudoers rule (password asked once)..."
  echo "$SUDOERS_LINE" | sudo tee "$SUDOERS_FILE" >/dev/null
  sudo chmod 440 "$SUDOERS_FILE"
  sudo visudo -cf "$SUDOERS_FILE"
fi

# Enable the watcher, run one sync now
systemctl --user daemon-reload
systemctl --user enable --now sddm-sync-watcher.service
systemctl --user restart sddm-sync-watcher.service
log "Watcher restarted. Running one sync now..."
bash "$SCRIPTS_DIR/sddm-sync.sh" --force

echo ""
echo "Done (v$VERSION). Test it:"
echo "  sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
echo "  tail -f $LOG_DIR/sync.log"
echo "Then change wallpaper in Super+W - SDDM should follow within ~3 seconds."
echo "Update later: bash install/install.sh   |   Check: bash install/install.sh --check"
echo "Uninstall:  bash install/install.sh --uninstall"
