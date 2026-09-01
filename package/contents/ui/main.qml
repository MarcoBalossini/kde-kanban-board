import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

import "dates.js" as Dates

PlasmoidItem {
    id: root

    // ---- palette -------------------------------------------------------
    // Curated accents that stay legible on both light and dark Breeze. No red
    // in here: red is what marks a card as important, and a list wearing it
    // would drown that out.
    readonly property var accents: [
        "#5b8def", // blue
        "#f0a63a", // amber
        "#3ec98a", // green
        "#a07df0", // violet
        "#3ec9c2"  // teal
    ]
    function accentColor(i) {
        var n = accents.length;
        return accents[((i % n) + n) % n];
    }

    // ---- config shortcuts ----------------------------------------------
    readonly property bool cfgShowCounts: Plasmoid.configuration.showCounts
    readonly property real cfgBackgroundAlpha: Plasmoid.configuration.backgroundOpacity / 100
    readonly property bool cfgCompactCards: Plasmoid.configuration.compactCards
    readonly property bool cfgStrikeDone: Plasmoid.configuration.strikeDone
    readonly property bool cfgHideDone: Plasmoid.configuration.hideDone
    readonly property int columnCount: columnsModel.count

    // How wide the board wants to be: every list at its configured width, the
    // add-list strip, the gaps between them and the outer margins. The popup
    // opens at this size instead of a fixed guess that would clip the last
    // list or pad empty space beside it.
    readonly property int boardNaturalWidth: {
        var n = Math.max(1, columnCount);
        return n * Plasmoid.configuration.columnWidth
             + Math.round(Kirigami.Units.gridUnit * 2.5)
             + Kirigami.Units.largeSpacing * n
             + Kirigami.Units.largeSpacing * 2;
    }

    // ---- state ---------------------------------------------------------
    property bool boardLoaded: false
    property Item dragLayer: null
    property Item boardItem: null
    property int openCount: 0
    property int doneCount: 0
    property int overdueCount: 0

    // Today, as cards store it. Cards colour themselves by how far off their
    // deadline is, so the board has to notice the date turning over: a widget
    // left open overnight would go on calling yesterday "Today".
    property string todayIso: Dates.toIso(new Date())

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            var t = Dates.toIso(new Date());
            if (t !== root.todayIso) {
                root.todayIso = t;
                root.recount();
            }
        }
    }

    // Roles: name, accent, sectionsJson. A list holds one or more vertical
    // sections, each with its own cards. Everything lives in the model rather
    // than in the delegates so that rebuilding a delegate can never lose it.
    ListModel { id: columnsModel }

    function sectionsOf(i) {
        try {
            return JSON.parse(columnsModel.get(i).sectionsJson) || [];
        } catch (e) {
            return [];
        }
    }

    function storeSections(i, arr) {
        if (i < 0 || i >= columnsModel.count) return;
        columnsModel.setProperty(i, "sectionsJson", JSON.stringify(arr));
        scheduleSave();
    }

    // A v1 list, or any list saved before it was ever split, is one nameless
    // section holding every card.
    function sectionsFrom(c) {
        var out = [];
        if (c.sections && c.sections.length > 0) {
            for (var i = 0; i < c.sections.length; i++) {
                var s = c.sections[i];
                out.push({ id: s.id || newId(), name: s.name || "",
                           collapsed: s.collapsed === true, tasks: s.tasks || [] });
            }
        } else {
            out.push({ id: newId(), name: "", collapsed: false, tasks: c.tasks || [] });
        }
        return out;
    }

    // ---- persistence ---------------------------------------------------
    function defaultBoard() {
        return {
            version: 2,
            columns: [
                { name: i18n("To Do"),       accent: 0, tasks: [] },
                { name: i18n("In Progress"), accent: 1, tasks: [] },
                { name: i18n("Done"),        accent: 2, tasks: [] }
            ]
        };
    }

    function newId() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36);
    }

    function load() {
        var data = null;
        try {
            if (Plasmoid.configuration.boardData)
                data = JSON.parse(Plasmoid.configuration.boardData);
        } catch (e) {
            data = null;
        }
        if (!data || !data.columns || data.columns.length === 0)
            data = defaultBoard();

        columnsModel.clear();
        for (var i = 0; i < data.columns.length; i++) {
            var c = data.columns[i];
            columnsModel.append({
                name: c.name || i18n("List"),
                accent: (c.accent === undefined) ? i : c.accent,
                sectionsJson: JSON.stringify(sectionsFrom(c))
            });
        }

        boardLoaded = true;
        recount();
    }

    function serialize() {
        var cols = [];
        for (var i = 0; i < columnsModel.count; i++) {
            var c = columnsModel.get(i);
            cols.push({ name: c.name, accent: c.accent, sections: sectionsOf(i) });
        }
        return JSON.stringify({ version: 2, columns: cols });
    }

    function recount() {
        var open = 0, done = 0, late = 0;
        for (var i = 0; i < columnsModel.count; i++) {
            var secs = sectionsOf(i);
            for (var j = 0; j < secs.length; j++) {
                var tasks = secs[j].tasks || [];
                for (var k = 0; k < tasks.length; k++) {
                    if (tasks[k].done) {
                        done++;
                        continue;
                    }
                    open++;
                    var d = Dates.daysUntil(tasks[k].due);
                    if (!isNaN(d) && d < 0) late++;
                }
            }
        }
        openCount = open;
        doneCount = done;
        overdueCount = late;
    }

    function scheduleSave() {
        if (!boardLoaded) return;
        recount();
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 350
        onTriggered: Plasmoid.configuration.boardData = root.serialize()
    }

    // ---- column ops ----------------------------------------------------
    function addColumn() {
        columnsModel.append({ name: i18n("New list"),
                              accent: columnsModel.count % accents.length,
                              sectionsJson: JSON.stringify(sectionsFrom({})) });
        scheduleSave();
        if (boardItem)
            boardItem.scrollToEnd();
    }

    function removeColumn(index) {
        if (columnsModel.count <= 1) return;
        columnsModel.remove(index);
        scheduleSave();
    }

    function renameColumn(index, name) {
        columnsModel.setProperty(index, "name", name);
        scheduleSave();
    }

    function cycleAccent(index) {
        var a = columnsModel.get(index).accent;
        columnsModel.setProperty(index, "accent", (a + 1) % accents.length);
        scheduleSave();
    }

    function moveColumn(from, to) {
        if (from === to || to < 0 || to >= columnsModel.count) return;
        columnsModel.move(from, to, 1);
        scheduleSave();
    }

    // ---- plasmoid wiring ----------------------------------------------
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // On the desktop the board *is* the widget. In a panel it cannot be: the
    // panel would stretch to fit it. There the applet is an icon and the board
    // lives in the popup behind it.
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                 || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    preferredRepresentation: inPanel ? compactRepresentation : fullRepresentation

    toolTipMainText: Plasmoid.configuration.boardTitle
    toolTipSubText: {
        if (openCount === 0) return i18n("Nothing pending");
        var s = i18np("%1 open task", "%1 open tasks", openCount);
        if (overdueCount > 0)
            s += " — " + i18np("%1 overdue", "%1 overdue", overdueCount);
        return s;
    }

    Component.onCompleted: load()

    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        // The panel imposes one axis and asks for the other; ask back for a
        // square so the icon is never letterboxed. Only the free axis is bound
        // to the imposed one, so there is no cycle.
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: vertical ? Kirigami.Units.iconSizes.small : compact.height
        Layout.preferredHeight: vertical ? compact.width : Kirigami.Units.iconSizes.small

        Kirigami.Icon {
            anchors.fill: parent
            // The bundled logo, not a theme name: the icon only lands in the
            // icon theme when install.sh puts it there, and the panel should
            // show it either way.
            source: Qt.resolvedUrl("../icons/org.kde.plasma.kanbanboard.svg")
            active: compact.containsMouse
        }
        Rectangle {
            visible: root.openCount > 0
            anchors { right: parent.right; top: parent.top }
            height: Math.round(parent.height * 0.5)
            width: Math.max(height, badge.implicitWidth + Kirigami.Units.smallSpacing)
            radius: height / 2
            color: root.overdueCount > 0 ? Kirigami.Theme.negativeTextColor
                                         : root.accentColor(0)
            PC3.Label {
                id: badge
                anchors.centerIn: parent
                text: root.openCount
                color: "white"
                font.pixelSize: Math.max(8, Math.round(parent.height * 0.68))
                font.bold: true
            }
        }
    }

    // ---- full representation -------------------------------------------
    fullRepresentation: FocusScope {
        id: board

        property alias columns: columnRepeater
        function scrollToEnd() {
            boardFlick.contentX = Math.max(0, boardFlick.contentWidth - boardFlick.width);
        }

        Component.onCompleted: {
            root.boardItem = board;
            root.dragLayer = dragLayerItem;
            root.recount();
        }

        // The popup is sized from these hints: the shell reads
        // Layout.preferredWidth off the full representation and, if it is not
        // above zero, falls back to a fixed default far narrower than a board.
        // So the hint must never depend on anything that reads zero early --
        // Screen.desktopAvailableWidth does, before the item has a window, and
        // clamping against it collapsed the hint into that fallback. Plasma
        // already fits the popup to the screen on its own.
        //
        // columnRow is the truth about how wide the lists came out; the
        // arithmetic estimate stands in for it until the delegates exist.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Math.max(Layout.minimumWidth,
                                        root.boardNaturalWidth,
                                        columnRow.implicitWidth
                                            + Kirigami.Units.largeSpacing * 2)
        Layout.preferredHeight: Kirigami.Units.gridUnit * 24

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 2
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                           Kirigami.Theme.backgroundColor.g,
                           Kirigami.Theme.backgroundColor.b,
                           root.cfgBackgroundAlpha)
            border.width: root.cfgBackgroundAlpha > 0 ? 1 : 0
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.10 * root.cfgBackgroundAlpha)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Left clicks that hit no control stop here: letting them through would
        // reach the containment and flip the desktop into edit mode mid-rename.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: mouse => mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // columns --------------------------------------------------
            Flickable {
                id: boardFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: columnRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: columnRow
                    height: boardFlick.height
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        id: columnRepeater
                        model: columnsModel
                        delegate: KanbanColumn {
                            board: root
                            columnIndex: index
                            columnName: model.name
                            accentIndex: model.accent
                            sectionsJson: model.sectionsJson
                            Layout.preferredWidth: Plasmoid.configuration.columnWidth
                            Layout.fillHeight: true
                        }
                    }

                    // add-list affordance
                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: addCol.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                                        : "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.smallMedium
                                height: width
                                source: "list-add"
                                opacity: 0.45
                            }
                            MouseArea {
                                id: addCol
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addColumn()
                            }
                        }
                    }
                }
            }
        }

        // floating layer that dragged cards reparent into
        Item {
            id: dragLayerItem
            anchors.fill: parent
            z: 1000
        }
    }
}
