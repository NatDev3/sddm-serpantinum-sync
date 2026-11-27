# Changelog

## 1.1.0 - 28 Nov 2026

- Re-running the installer no longer reinstalls blindly - it asks what to do: update, reinstall, uninstall, or cancel
- Update replaces only the scripts, keeps settings and backups, and skips the dependency and sudoers steps
- `sddm-sync update` re-applies the stored installer version; `--update` and `--reinstall` flags for scripted use
- Version-aware: update is only offered when the installer is newer than the installed version

## 1.0.0 - 26 Nov 2026

- SDDM follows your Serpantinum wallpaper - background and colours sync automatically, in dark and light mode
- Image wallpapers are copied; video wallpapers get a still frame extracted with ffmpeg
- Syncs once on login, so changes made while logged out aren't missed
- `sddm-sync` command: `sync`, `check`, `log`, `status`, `version`, `uninstall`
- Clean uninstall - restores the original theme and removes everything it installed
- Log rotation, so `sync.log` never grows forever

Known issues:

- Light-mode palette is approximate when the desktop is in Light mode
- A wallpaper change can sync twice in the log - harmless, same colours both times
- If the SDDM theme format changes, the sync fails loudly instead of silently patching the wrong thing
