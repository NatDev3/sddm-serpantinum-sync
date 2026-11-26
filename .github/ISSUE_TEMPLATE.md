---
name: Bug report
about: SDDM didn't sync, or colours / background are wrong
labels: bug
---

**Serpantinum version:** <!-- e.g. 2.5.2, `serpantinum --version` -->
**Installer version:** <!-- `bash install/install.sh --version` -->
**Wallpaper type:** <!-- image / video (.mp4/.webm) -->
**Desktop mode:** <!-- dark / light -->

**What happened:**

**What should have happened:**

**Log output:**
```
tail -30 ~/.local/state/sddm-sync/sync.log
```

**Watcher status:**
```
systemctl --user status sddm-sync-watcher.service --no-pager
```

**Palette (first 10 lines):**
```
cat ~/.local/state/serpantinum/qs_matugen_colors.json
```
