# Changelog

## 1.2.0 - 28 Nov 2026

- Fixed the watcher never sync after reboot
- Sync now reports clear eror instead line number
- The watcher restart automaticly if it ever exist
- Instaler no longer hardcodes the username as a fallback

## 1.1.0 - 28 Nov 2026

- Re-running the installer no longer reinstalls blindly 
- Update replaces only the scripts, keeps settings and backups, and skips the dependency and sudoers steps
- `sddm-sync update` re-applies the stored installer version

## 1.0.0 - 26 Nov 2026

- SDDM follows your Serpantinum wallpaper, background and colours sync automaticall in dark and light mode
- Image wallpapers are copied; video wallpapers get a still frame extracted 
- Syncs once on login
- Clean uninstall 


Known issues:

- Light-mode palette is approximate when the desktop is in Light mode
- A wallpaper change can sync twice in the log - harmless, same colours both times
- If the SDDM theme format changes, the sync fails loudly instead of silently patching the wrong thing
