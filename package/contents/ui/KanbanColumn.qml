import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: column

    // set by the Repeater in main.qml
    property var board
    property int columnIndex: 0
    property string columnName: ""
    property int accentIndex: 0
    // Seed data; also the persistence target (written back through
    // board.storeSections). A list holds one or more vertical sections, each
    // with its own cards.
    property string sectionsJson: "[]"

    readonly property color accent: board.accentColor(accentIndex)
    readonly property bool compact: board.cfgCompactCards
    readonly property int sectionCount: sectionsModel.count

    // ListModel role reads are not reactive; bump to re-evaluate derived values
    property int revision: 0

    // A list nobody has split holds a single nameless section and draws no
    // section chrome at all.
    readonly property bool plainMode: {
        revision;
        return sectionsModel.count === 1 && sectionsModel.get(0)
               && sectionsModel.get(0).name.length === 0;
    }

    // Roles: sectionId, name, collapsed, tasksJson
    ListModel { id: sectionsModel }

    Component.onCompleted: {
        var seed = [];
        try {
            seed = JSON.parse(sectionsJson) || [];
        } catch (e) {
            seed = [];
        }
        if (seed.length === 0)
            seed = [{ id: board.newId(), name: "", collapsed: false, tasks: [] }];
        for (var i = 0; i < seed.length; i++) {
            var s = seed[i];
            sectionsModel.append({
                sectionId: s.id || board.newId(),
                name: s.name || "",
                collapsed: s.collapsed === true,
                tasksJson: JSON.stringify(s.tasks || [])
            });
        }
        revision++;
    }

    function sectionAt(i) {
        return sectionRepeater.itemAt(i);
    }

    // Sections announce themselves once created so counters that read through
    // the live items re-evaluate.
    function registerSection(item) {
        revision++;
    }

    function taskArrayOf(i) {
        var it = sectionAt(i);
        if (it) return it.taskArray();
        try {
            return JSON.parse(sectionsModel.get(i).tasksJson) || [];
        } catch (e) {
            return [];
        }
    }

    // ---- persistence -----------------------------------------------------
    function persist() {
        var arr = [];
        for (var i = 0; i < sectionsModel.count; i++) {
            var s = sectionsModel.get(i);
            var tasks = [];
            try {
                tasks = JSON.parse(s.tasksJson) || [];
            } catch (e) {
                tasks = [];
            }
            arr.push({ id: s.sectionId, name: s.name,
                       collapsed: s.collapsed === true, tasks: tasks });
        }
        revision++;
        board.storeSections(columnIndex, arr);
    }

    // called by a section whenever its cards changed
    function storeSectionTasks(i, arr) {
        if (i < 0 || i >= sectionsModel.count) return;
        sectionsModel.setProperty(i, "tasksJson", JSON.stringify(arr));
        persist();
    }

    // ---- section ops -----------------------------------------------------
    // Splitting a list that already holds cards has to put those cards
    // somewhere: they stay together in a block of their own.
    function addSection(name, at) {
        var label = (name && name.length > 0) ? name : i18n("New section");
        if (plainMode) {
            if (taskArrayOf(0).length === 0) {
                sectionsModel.setProperty(0, "name", label);
                persist();
                return 0;
            }
            sectionsModel.setProperty(0, "name", i18n("Unsorted"));
        }
        var idx = (at === undefined || at < 0 || at > sectionsModel.count)
                  ? sectionsModel.count : at;
        sectionsModel.insert(idx, { sectionId: board.newId(), name: label,
                                    collapsed: false, tasksJson: "[]" });
        persist();
        return idx;
    }

    // Add a block and drop straight into renaming it — a block is only useful
    // once it is named.
    function beginAddSection(at) {
        var idx = addSection("", at);
        Qt.callLater(function() {
            var s = column.sectionAt(idx);
            if (s) s.startRename();
        });
    }

    function renameSection(i, name) {
        var t = name.trim();
        if (t.length === 0) return;
        sectionsModel.setProperty(i, "name", t);
        persist();
    }

    function setSectionCollapsed(i, v) {
        sectionsModel.setProperty(i, "collapsed", v === true);
        persist();
    }

    function moveSection(from, to) {
        if (from === to || to < 0 || to >= sectionsModel.count) return;
        sectionsModel.move(from, to, 1);
        persist();
    }

    // Deleting a block must never delete work: its cards join the neighbour
    // above, or below when it is the first block.
    function removeSection(i) {
        if (sectionsModel.count <= 1) return;
        var into = i > 0 ? i - 1 : 1;
        var mine = taskArrayOf(i);
        var target = sectionAt(into);
        if (target) {
            target.absorb(mine, into > i);
        } else {
            var merged = into > i ? mine.concat(taskArrayOf(into))
                                  : taskArrayOf(into).concat(mine);
            sectionsModel.setProperty(into, "tasksJson", JSON.stringify(merged));
        }
        sectionsModel.remove(i);
        persist();
    }

    // Back to one plain block, keeping every card in list order.
    function mergeSections() {
        var all = [];
        for (var i = 0; i < sectionsModel.count; i++)
            all = all.concat(taskArrayOf(i));
        var first = sectionAt(0);
        if (first) first.replaceTasks(all);
        else sectionsModel.setProperty(0, "tasksJson", JSON.stringify(all));
        while (sectionsModel.count > 1)
            sectionsModel.remove(sectionsModel.count - 1);
        sectionsModel.setProperty(0, "name", "");
        persist();
    }

    // ---- list-wide task API ----------------------------------------------
    // Convenience wrappers that act on the list's first block; the cards
    // themselves talk to their own section.
    readonly property var tasksModel: {
        revision;
        var s = sectionAt(0);
        return s ? s.tasksModel : null;
    }

    function addTask(text, atTop) {
        var s = sectionAt(0);
        if (s) s.addTask(text, atTop);
    }
    function removeTask(i) {
        var s = sectionAt(0);
        if (s) s.removeTask(i);
    }
    function toggleDone(i) {
        var s = sectionAt(0);
        if (s) s.toggleDone(i);
    }
    function toggleImportant(i) {
        var s = sectionAt(0);
        if (s) s.toggleImportant(i);
    }
    function setText(i, text) {
        var s = sectionAt(0);
        if (s) s.setText(i, text);
    }
    function touch() {
        var s = sectionAt(0);
        if (s) s.touch();
    }
    function dropIndexFor(y) {
        var s = sectionAt(0);
        return s ? s.dropIndexFor(y) : 0;
    }
    function acceptDrop(sourceCard, idx) {
        var s = sectionAt(0);
        if (!s) return;
        // A source that names a whole list means that list's first block.
        var src = sourceCard.columnItem;
        var holder = (src && src.sectionAt) ? src.sectionAt(0) : src;
        s.acceptDrop({ columnItem: holder, taskIndex: sourceCard.taskIndex }, idx);
    }

    function clearCompleted() {
        for (var i = 0; i < sectionsModel.count; i++) {
            var s = sectionAt(i);
            if (s) s.clearCompleted();
        }
    }

    function beginCompose() {
        var s = sectionAt(0);
        if (s) s.beginCompose();
    }

    readonly property int openTasks: {
        revision;
        var n = 0;
        for (var i = 0; i < sectionsModel.count; i++) {
            var arr = taskArrayOf(i);
            for (var j = 0; j < arr.length; j++)
                if (!arr[j].done) n++;
        }
        return n;
    }

    readonly property int doneTasks: {
        revision;
        var n = 0;
        for (var i = 0; i < sectionsModel.count; i++) {
            var arr = taskArrayOf(i);
            for (var j = 0; j < arr.length; j++)
                if (arr[j].done) n++;
        }
        return n;
    }

    // ---- visuals -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius * 1.5
        // A translucent accent wash rather than a tint, so whatever is behind the
        // widget still shows through. Deliberately weaker than the cards sitting
        // on top of it.
        color: Qt.alpha(column.accent, 0.06)
        border.width: 1
        border.color: Qt.alpha(column.accent, 0.16)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        // header ---------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing / 2
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.smallSpacing
                height: width
                radius: width / 2
                color: column.accent
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: board.cycleAccent(column.columnIndex)
                }
            }

            PC3.Label {
                id: title
                visible: !renameField.visible
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                text: column.columnName
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.weight: Font.DemiBold
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize

                // Covers the full row height, not just the glyphs: a double click
                // that misses would fall through to the containment.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: mouse => mouse.accepted = true
                    onDoubleClicked: mouse => {
                        mouse.accepted = true;
                        column.startRename();
                    }
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) colMenu.popup() }
                }
            }

            PC3.TextField {
                id: renameField
                visible: false
                Layout.fillWidth: true
                onAccepted: commitRename()
                onActiveFocusChanged: if (!activeFocus && visible) commitRename()
                Keys.onEscapePressed: { visible = false; }
            }

            PC3.Label {
                visible: board.cfgShowCounts && !renameField.visible && column.openTasks > 0
                text: column.openTasks
                opacity: 0.45
                font: Kirigami.Theme.smallFont
            }

            PC3.ToolButton {
                icon.name: "list-add"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
                opacity: hovered ? 1.0 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }
                onClicked: column.beginCompose()
            }

            PC3.ToolButton {
                icon.name: "overflow-menu"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
                opacity: hovered ? 1.0 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }
                onClicked: colMenu.popup()
            }
        }

        // sections ---------------------------------------------------------
        // The whole stack of blocks scrolls as one, so a block is exactly as
        // tall as its cards instead of owning a scroll area of its own.
        Flickable {
            id: bodyFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: stack.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: stack
                width: bodyFlick.width
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    id: sectionRepeater
                    model: sectionsModel
                    delegate: KanbanSection {
                        board: column.board
                        ownerColumn: column
                        sectionIndex: index
                        sectionName: model.name
                        collapsed: model.collapsed
                        tasksJson: model.tasksJson
                        availableHeight: bodyFlick.height
                        Layout.fillWidth: true
                    }
                }

                // add-section affordance, only once a list has been split
                Rectangle {
                    id: addSectionRow
                    visible: !column.plainMode
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    radius: Kirigami.Units.cornerRadius
                    color: addSectionArea.containsMouse
                           ? Qt.alpha(Kirigami.Theme.textColor, 0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "list-add"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.5
                        }
                        PC3.Label {
                            text: i18n("Add section")
                            opacity: 0.5
                            font: Kirigami.Theme.smallFont
                        }
                    }

                    MouseArea {
                        id: addSectionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: column.beginAddSection(-1)
                    }
                }
            }
        }
    }

    // ---- menu ------------------------------------------------------------
    PC3.Menu {
        id: colMenu
        PC3.MenuItem {
            text: i18n("Add task")
            icon.name: "list-add"
            onTriggered: column.beginCompose()
        }
        PC3.MenuItem {
            text: i18n("Rename list")
            icon.name: "edit-rename"
            onTriggered: column.startRename()
        }
        PC3.MenuItem {
            text: i18n("Next color")
            icon.name: "color-picker"
            onTriggered: board.cycleAccent(column.columnIndex)
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: column.plainMode ? i18n("Split into sections") : i18n("Add section")
            icon.name: "split"
            onTriggered: column.beginAddSection(-1)
        }
        PC3.MenuItem {
            text: i18n("Merge sections")
            icon.name: "kt-remove-filters"
            enabled: !column.plainMode
            onTriggered: column.mergeSections()
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: i18n("Move left")
            icon.name: "arrow-left"
            enabled: column.columnIndex > 0
            onTriggered: board.moveColumn(column.columnIndex, column.columnIndex - 1)
        }
        PC3.MenuItem {
            text: i18n("Move right")
            icon.name: "arrow-right"
            enabled: column.columnIndex < board.columnCount - 1
            onTriggered: board.moveColumn(column.columnIndex, column.columnIndex + 1)
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: i18n("Clear completed")
            icon.name: "edit-clear-all"
            enabled: column.doneTasks > 0
            onTriggered: column.clearCompleted()
        }
        PC3.MenuItem {
            text: i18n("Delete list")
            icon.name: "edit-delete"
            enabled: board.columnCount > 1
            onTriggered: board.removeColumn(column.columnIndex)
        }
    }

    function startRename() {
        renameField.text = column.columnName;
        renameField.visible = true;
        renameField.forceActiveFocus();
        renameField.selectAll();
    }

    function commitRename() {
        if (!renameField.visible) return;
        renameField.visible = false;
        var t = renameField.text.trim();
        if (t.length > 0 && t !== column.columnName)
            board.renameColumn(column.columnIndex, t);
    }
}
