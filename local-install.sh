#!/bin/bash
# local-install.sh
# Builds mic-warm from this checkout and installs it as a LaunchAgent.
#
# This fork does not download prebuilt binaries. The script compiles the
# source you have checked out and makes no network calls. Review the source
# (and any upstream changes you merged) before running it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/mic-warm"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.keep-mic-warm.plist"
LOG_PATH="$HOME/Library/Logs/mic-warm.log"

cd "$SCRIPT_DIR"

echo "Building mic-warm from $(git rev-parse --short HEAD 2>/dev/null || echo 'local source')..."
# --disable-automatic-resolution stops SwiftPM from fetching any package.
# The package has no dependencies; if one is ever added, this build fails
# instead of downloading it.
swift build -c release --disable-automatic-resolution
BUILT="$(swift build -c release --show-bin-path)/mic-warm"

# Stop the running agent before replacing the binary.
launchctl unload "$PLIST_PATH" 2>/dev/null || true

mkdir -p "$BIN_DIR" "$(dirname "$PLIST_PATH")" "$(dirname "$LOG_PATH")"
install -m 755 "$BUILT" "$BIN_PATH"
install -m 755 "$SCRIPT_DIR/mic-warmctl" "$BIN_DIR/mic-warmctl"

# Ad-hoc code sign so macOS TCC tracks a stable identity.
codesign --force --sign - "$BIN_PATH"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.keep-mic-warm</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>${LOG_PATH}</string>
    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>
</dict>
</plist>
EOF

# Clear any "mic-warmctl stop" override; installing means you want it on.
launchctl enable "gui/$(id -u)/com.user.keep-mic-warm"
launchctl load "$PLIST_PATH"

echo ""
echo "Installed and running."
echo "macOS will prompt you to grant mic-warm microphone access."
echo "Allow it in System Settings > Privacy & Security > Microphone."
echo ""
echo "Log file: $LOG_PATH"
echo "Stop/start:   mic-warmctl stop | mic-warmctl start | mic-warmctl status"
echo "To uninstall: ./uninstall.sh"
