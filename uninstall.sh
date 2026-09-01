#!/usr/bin/env bash
set -euo pipefail
ID="org.kde.plasma.kanbanboard"
kpackagetool6 --type Plasma/Applet --remove "$ID"
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/$ID.svg"
