#!/usr/bin/env bash
# Install / update the Kanban Board plasmoid for the current user.
#
#   ./install.sh            install or upgrade
#   ./install.sh --restart  ... and restart plasmashell so a widget that is
#                           already on the desktop picks up the new QML
set -euo pipefail

ID="org.kde.plasma.kanbanboard"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/package"
RESTART=0
[[ "${1:-}" == "--restart" ]] && RESTART=1

# --upgrade handles both cases, but it removes the old copy first: if it then
# fails the package is simply gone, so fall back to a plain install.
if ! kpackagetool6 --type Plasma/Applet --upgrade "$DIR" 2>/dev/null; then
    kpackagetool6 --type Plasma/Applet --install "$DIR"
fi

if ! kpackagetool6 --type Plasma/Applet --show "$ID" >/dev/null 2>&1; then
    echo "error: $ID is not installed after the attempt" >&2
    exit 1
fi

# The widget list looks the applet icon up by theme name, so the bundled logo
# has to exist in the user's icon theme as well as inside the package.
ICONDIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
mkdir -p "$ICONDIR"
cp "$DIR/contents/icons/$ID.svg" "$ICONDIR/$ID.svg"
touch "$ICONDIR/.." 2>/dev/null || true

# Plasma compiles applet QML into a disk cache; stale entries survive an upgrade.
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/plasmashell/qmlcache" \
       "${XDG_CACHE_HOME:-$HOME/.cache}/qmlcache" 2>/dev/null || true

echo "Installed $ID"

if (( RESTART )); then
    echo "Restarting plasmashell ..."
    (kquitapp6 plasmashell >/dev/null 2>&1 || killall plasmashell >/dev/null 2>&1) || true
    sleep 2
    (setsid plasmashell >/dev/null 2>&1 &)
    echo "Done."
else
    echo
    echo "New widget: right-click the desktop -> Add Widgets -> \"Kanban Board\"."
    echo "Already on the desktop? plasmashell keeps the old QML in memory until it"
    echo "restarts -- rerun as:  ./install.sh --restart"
fi
