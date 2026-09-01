#!/usr/bin/env bash
# Headless logic tests for the column/card behaviour.
# i18n() is a plasmoid context function, so the UI files are copied into a
# temp dir with it stubbed out before running.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI="$HERE/../package/contents/ui"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp "$UI"/KanbanColumn.qml "$UI"/KanbanSection.qml "$UI"/TaskCard.qml \
   "$UI"/TaskComposer.qml "$UI"/DuePicker.qml "$UI"/dates.js "$TMP/"
# i18np() too: a plural form is still a plasmoid context function.
sed -i 's/\bi18np\?(/String(/g' "$TMP"/*.qml
cp "$HERE/tst_kanban.qml" "$TMP/"

QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -import /usr/lib64/qt6/qml -input "$TMP/tst_kanban.qml"
