#!/bin/bash
# Installs CleanMyMac: the script, the Desktop app and a weekly Quick Clean.
#   ./install.sh                 install everything
#   ./install.sh --no-schedule   skip the weekly auto-clean
#   ./install.sh --uninstall     remove everything
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/CleanMyMac"
APP="$HOME/Desktop/CleanMyMac.app"
LABEL="com.vihangashamod.cleanmymac"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  rm -rf "$DEST" "$APP"
  echo "CleanMyMac removed."
  exit 0
fi

mkdir -p "$DEST"
install -m 755 "$HERE/cleanmymac.sh" "$DEST/cleanmymac.sh"
echo "✔ Script  → $DEST/cleanmymac.sh"

rm -rf "$APP"
osacompile -o "$APP" "$HERE/app/CleanMyMac.applescript"
echo "✔ App     → $APP"

if [ "${1:-}" != "--no-schedule" ]; then
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DEST/cleanmymac.sh</string>
    <string>--quick</string>
    <string>--notify</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>0</integer>
    <key>Hour</key><integer>10</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/dev/null</string>
  <key>StandardErrorPath</key><string>/dev/null</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "✔ Weekly Quick Clean → Sundays 10:00 (notification when done)"
fi
