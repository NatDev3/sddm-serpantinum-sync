# Security Policy

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

This installer writes a passwordless sudoers rule and copies files into
`/usr/share/sddm/themes/`, so a bug there matters. Report it privately:

- Open a GitHub issue only for non-security bugs, or
- Email the maintainer (see the repo profile) with:
  - What the issue is, and what an attacker could do with it
  - Steps to reproduce, if you have them
  - The installer version (`bash install/install.sh --version`)

You will get a reply, and a fix before any public disclosure.

## What is in scope

- The sudoers rule (`/etc/sudoers.d/sddm-sync`) - it must allow only the
  exact `cp` / `chmod` commands, from the private runtime dir only, never `/tmp`
- The installer, the sync script, and the watcher - no network calls home,
  no telemetry, no downloads except the theme (from Darkkal44/qylock) and
  packages (from pacman / AUR)
- File permissions on the installed theme (`644`) and the runtime dir (`0700`)

## Supported versions

The latest `1.x` release is supported.
