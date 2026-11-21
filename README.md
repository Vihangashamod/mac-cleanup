# CleanMyMac

Scan your Mac, choose what to clean, clean it. One click or one command.

## Install

```bash
git clone https://github.com/Vihangashamod/mac-cleanup.git
cd mac-cleanup && ./install.sh
```

This installs:
- `CleanMyMac.app` on your Desktop
- the script at `~/Library/Application Support/CleanMyMac/cleanmymac.sh`
- a weekly Quick Clean (Sundays 10:00, with a notification). Skip it with `./install.sh --no-schedule`.

Remove everything with `./install.sh --uninstall`.

## Use

**App:** double-click `CleanMyMac.app`.
- **Quick Clean**: the safe everyday set, in one click.
- **Advanced…**: scans your Mac and lists only what it found, with sizes. Tick what you want and see the total before anything is removed.

**Terminal:**

```bash
cleanmymac.sh                      # interactive menu
cleanmymac.sh --quick              # safe everyday clean
cleanmymac.sh --items claude,xcode # specific items
cleanmymac.sh --dry-run            # preview everything, remove nothing
cleanmymac.sh --list               # all item ids
```

## What it can clean

| Quick (safe) | Advanced (you choose) |
|---|---|
| System & app caches, logs | Empty Trash |
| VS Code, Notion, Chrome/Brave code caches | Claude vm_bundles |
| Spotify, npm caches | Xcode DerivedData, Gradle, Homebrew, Conda |
| Python `__pycache__`, Word `~$` temp files | Docker unused images & containers (volumes kept) |
| | `node_modules`, `.next` and venvs in projects idle 7+ days |
| | Old installers and duplicate downloads (moved to Trash) |
| | Free RAM and reset font & DNS caches (asks for password) |
| | List files over 500 MB (report only) |

## Safety

- Apps that are open (Claude, VS Code, Notion, Spotify, browsers) are skipped, not broken.
- Downloads are moved to the Trash, so **Put Back** still works.
- Build folders are only removed from projects with no edits in 7 days. `~/Desktop/Programming` is never touched.
- Each run is logged to `~/Library/Logs/CleanMyMac.log`.
- "Freed" is measured from the disk itself (`df`), not estimated.
