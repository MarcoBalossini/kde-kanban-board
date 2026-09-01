import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// One block inside a list: an optional header plus its own stack of cards.
// A list that was never split holds exactly one nameless section, which renders
// without any chrome, so an unsplit board looks exactly as it did before.
Item {
    id: section

    // set by the Repeater in KanbanColumn.qml
    property var board
    property var ownerColumn
    property int sectionIndex: 0
    property string sectionName: ""
    property bool collapsed: false
    // Seed data; kept current through touch() so a rebuilt delegate reseeds
    // from the same tasks it had.
    property string tasksJson: "[]"
    // Viewport height the column can offer. Only the sole block of an unsplit
    // list stretches into it; split blocks size to their cards.
    property real availableHeight: 0

    readonly property color accent: ownerColumn.accent
    readonly property alias tasksModel: tasksModel
    // Natural height of the cards this block holds.
    readonly property real contentHeight: taskList.contentHeight
    readonly property bool headerVisible: !ownerColumn.plainMode
    readonly property real inset: headerVisible ? Math.round(Kirigami.Units.smallSpacing / 2) : 0
    readonly property real gap: headerVisible ? Math.round(Kirigami.Units.smallSpacing / 2)
                                              : Kirigami.Units.smallSpacing
    // Only a floor for a block with nothing to show: an empty one folds itself
    // up, so this is what is left when every card in it is a hidden completed
    // one, or when a drag is hovering over it. A block that holds cards is as
    // tall as those cards and not a pixel more.
    readonly property real minBody: Kirigami.Units.gridUnit * 1.2

    // Expanding an empty block is a transient choice: it folds itself back up
    // once it is empty again.
    property bool userExpanded: false
    // An empty block is worth a title strip, not a third of the list's height.
    readonly property bool autoCollapsed: headerVisible && !collapsed
                                          && !userExpanded && tasksModel.count === 0
    readonly property bool effectiveCollapsed: collapsed || autoCollapsed

    property bool dropActive: false
    property int dropIndex: -1
    // ListModel role reads are not reactive; bump to re-evaluate derived values
    property int revision: 0

    readonly property real stretchBody:
        Math.max(minBody,
                 availableHeight - 2 * inset - composer.implicitHeight - layout.spacing
                 - (headerVisible ? headerRow.implicitHeight + layout.spacing : 0))
    // An unsplit list is one block filling the column, and it scrolls inside
    // itself so the "Add task" row stays pinned to the bottom. Split blocks are
    // exactly as tall as their cards and let the column scroll the whole stack.
    readonly property real bodyHeight:
        ownerColumn.plainMode ? stretchBody
                              : Math.max(taskList.contentHeight, minBody)

    implicitHeight: layout.implicitHeight + 2 * inset

    ListModel { id: tasksModel }

    Connections {
        target: tasksModel
        function onCountChanged() {
            if (tasksModel.count > 0) section.userExpanded = false;
        }
    }

    Component.onCompleted: {
        var seed = [];
        try {
            seed = JSON.parse(tasksJson) || [];
        } catch (e) {
            seed = [];
        }
        for (var i = 0; i < seed.length; i++)
            tasksModel.append(normalize(seed[i]));
        revision++;
        ownerColumn.registerSection(section);
    }

    function normalize(t) {
        return {
            taskId: t.id || t.taskId || board.newId(),
            text: t.text || "",
            done: t.done === true,
            important: t.important === true,
            created: t.created || 0
        };
    }

    // ---- task ops ------------------------------------------------------
    function touch() {
        revision++;
        ownerColumn.storeSectionTasks(sectionIndex, taskArray());
    }

    function taskArray() {
        var arr = [];
        for (var i = 0; i < tasksModel.count; i++) {
            var t = tasksModel.get(i);
            arr.push({ id: t.taskId, text: t.text, done: t.done,
                       important: t.important, created: t.created });
        }
        return arr;
    }

    // Used when blocks are merged: take someone else's cards without losing ours.
    function absorb(arr, atTop) {
        for (var i = 0; i < arr.length; i++)
            tasksModel.insert(atTop ? i : tasksModel.count, normalize(arr[i]));
        touch();
    }

    function replaceTasks(arr) {
        tasksModel.clear();
        for (var i = 0; i < arr.length; i++)
            tasksModel.append(normalize(arr[i]));
        touch();
    }

    function addTask(text, atTop) {
        var t = text.trim();
        if (t.length === 0) return;
        var entry = { taskId: board.newId(), text: t, done: false,
                      important: false, created: Date.now() };
        if (atTop) tasksModel.insert(0, entry);
        else tasksModel.append(entry);
        touch();
    }

    function removeTask(i) {
        tasksModel.remove(i);
        touch();
    }

    function toggleDone(i) {
        tasksModel.setProperty(i, "done", !tasksModel.get(i).done);
        touch();
    }

    function toggleImportant(i) {
        tasksModel.setProperty(i, "important", !tasksModel.get(i).important);
        touch();
    }

    function setText(i, text) {
        var t = text.trim();
        if (t.length === 0) { removeTask(i); return; }
        tasksModel.setProperty(i, "text", t);
        touch();
    }

    function clearCompleted() {
        for (var i = tasksModel.count - 1; i >= 0; i--)
            if (tasksModel.get(i).done) tasksModel.remove(i);
        touch();
    }

    readonly property int openTasks: {
        revision; // dependency
        var n = 0;
        for (var i = 0; i < tasksModel.count; i++)
            if (!tasksModel.get(i).done) n++;
        return n;
    }

    function beginCompose() {
        userExpanded = true;
        if (collapsed) ownerColumn.setSectionCollapsed(sectionIndex, false);
        composer.begin();
    }

    function toggleCollapsed() {
        if (effectiveCollapsed) {
            userExpanded = true;
            if (collapsed) ownerColumn.setSectionCollapsed(sectionIndex, false);
        } else {
            userExpanded = false;
            ownerColumn.setSectionCollapsed(sectionIndex, true);
        }
    }

    // ---- drag & drop ---------------------------------------------------
    // Where would a card dropped at block-local y land?
    function dropIndexFor(y) {
        var cy = y + taskList.contentY;
        for (var i = 0; i < tasksModel.count; i++) {
            var item = taskList.itemAtIndex(i);
            if (!item || item.height <= 0) continue;
            if (cy < item.y + item.height / 2) return i;
        }
        return tasksModel.count;
    }

    function indicatorY(idx) {
        if (tasksModel.count === 0) return 0;
        if (idx >= tasksModel.count) {
            var last = taskList.itemAtIndex(tasksModel.count - 1);
            return last ? last.y + last.height - taskList.contentY : 0;
        }
        var it = taskList.itemAtIndex(idx);
        return it ? it.y - taskList.contentY : 0;
    }

    // A card names the block it came from, so a move between two blocks of the
    // same list is the same operation as a move between two lists.
    function acceptDrop(sourceCard, idx) {
        var src = sourceCard.columnItem;
        var from = sourceCard.taskIndex;
        if (src === section) {
            var to = idx > from ? idx - 1 : idx;
            if (to !== from) tasksModel.move(from, to, 1);
        } else {
            var t = src.tasksModel.get(from);
            var copy = { taskId: t.taskId, text: t.text, done: t.done,
                         important: t.important, created: t.created };
            src.tasksModel.remove(from);
            tasksModel.insert(Math.min(idx, tasksModel.count), copy);
            src.touch();
        }
        touch();
    }

    // ---- visuals -------------------------------------------------------
    // Block chrome only exists once a list is split; an unsplit list draws
    // nothing here and keeps the plain look.
    Rectangle {
        anchors.fill: parent
        visible: section.headerVisible
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(section.accent, section.dropActive ? 0.12 : 0.04)
        border.width: 1
        border.color: section.dropActive ? Qt.alpha(section.accent, 0.55)
                                         : Qt.alpha(section.accent, 0.14)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: section.inset
        spacing: section.gap

        // header -----------------------------------------------------------
        RowLayout {
            id: headerRow
            visible: section.headerVisible
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2

            PC3.ToolButton {
                icon.name: section.effectiveCollapsed ? "arrow-right" : "arrow-down"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.small
                    + Math.round(Kirigami.Units.smallSpacing / 2)
                implicitHeight: implicitWidth
                opacity: hovered ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: 120 } }
                onClicked: section.toggleCollapsed()
            }

            PC3.Label {
                id: sectionTitle
                visible: !sectionRename.visible
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    + Math.round(Kirigami.Units.smallSpacing / 2)
                text: section.sectionName
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: Font.DemiBold
                opacity: 0.75

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: mouse => mouse.accepted = true
                    onDoubleClicked: mouse => {
                        mouse.accepted = true;
                        section.startRename();
                    }
                    onClicked: mouse => { if (mouse.button === Qt.RightButton) secMenu.popup() }
                }
            }

            PC3.TextField {
                id: sectionRename
                visible: false
                Layout.fillWidth: true
                font: Kirigami.Theme.smallFont
                onAccepted: section.commitRename()
                onActiveFocusChanged: if (!activeFocus && visible) section.commitRename()
                Keys.onEscapePressed: visible = false
            }

            PC3.Label {
                visible: board.cfgShowCounts && !sectionRename.visible && section.openTasks > 0
                // Left to itself a label is taller than the icon row and quietly
                // sets the height of every block header.
                Layout.preferredHeight: sectionTitle.Layout.preferredHeight
                verticalAlignment: Text.AlignVCenter
                text: section.openTasks
                opacity: 0.45
                font: Kirigami.Theme.smallFont
            }

            PC3.ToolButton {
                icon.name: "list-add"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.small
                    + Math.round(Kirigami.Units.smallSpacing / 2)
                implicitHeight: implicitWidth
                opacity: hovered ? 1.0 : 0.5
                onClicked: section.beginCompose()
            }

            PC3.ToolButton {
                icon.name: "overflow-menu"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.small
                    + Math.round(Kirigami.Units.smallSpacing / 2)
                implicitHeight: implicitWidth
                opacity: hovered ? 1.0 : 0.5
                onClicked: secMenu.popup()
            }
        }

        // tasks --------------------------------------------------------------
        Item {
            id: bodyItem
            visible: !section.effectiveCollapsed
            Layout.fillWidth: true
            Layout.preferredHeight: section.bodyHeight

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }

            ListView {
                id: taskList
                anchors.fill: parent
                interactive: ownerColumn.plainMode
                clip: ownerColumn.plainMode
                spacing: Kirigami.Units.smallSpacing
                model: tasksModel
                cacheBuffer: 4000
                boundsBehavior: Flickable.StopAtBounds

                delegate: TaskCard {
                    board: section.board
                    columnItem: section
                    taskIndex: index
                    width: taskList.width
                }

                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
                }
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                    NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 140 }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 120 }
                }
            }

            // empty hint
            PC3.Label {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit
                visible: tasksModel.count === 0 && !section.dropActive
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: section.headerVisible ? i18n("Empty") : i18n("Nothing here yet")
                opacity: 0.35
                font: Kirigami.Theme.smallFont
            }

            // drop indicator
            Rectangle {
                visible: section.dropActive && section.dropIndex >= 0
                x: 0
                y: Math.min(Math.max(0, section.indicatorY(section.dropIndex)),
                            parent.height - height)
                width: parent.width
                height: 2
                radius: 1
                color: section.accent
            }

            DropArea {
                anchors.fill: parent
                keys: ["kanban/task"]

                onEntered: drag => {
                    section.dropActive = true;
                    section.dropIndex = section.dropIndexFor(drag.y);
                }
                onPositionChanged: drag => {
                    section.dropIndex = section.dropIndexFor(drag.y);
                }
                onExited: {
                    section.dropActive = false;
                    section.dropIndex = -1;
                }
                onDropped: drop => {
                    var idx = section.dropIndexFor(drop.y);
                    section.dropActive = false;
                    section.dropIndex = -1;
                    if (drop.source && drop.source.columnItem)
                        section.acceptDrop(drop.source, idx);
                    drop.accept(Qt.MoveAction);
                }
            }
        }

        // composer -----------------------------------------------------------
        // A split list would waste a third of its height on three idle "Add
        // task" rows, so there the composer only appears while it is in use.
        TaskComposer {
            id: composer
            // Hidden rather than zero-height: a zero-height layout item still
            // costs the spacing on both sides of it.
            visible: !section.effectiveCollapsed
                     && (composer.active || composer.showIdleHint)
            Layout.fillWidth: true
            accent: section.accent
            showIdleHint: section.ownerColumn.plainMode
            onSubmitted: text => section.addTask(text, false)
        }
    }

    // A folded block still takes cards: the whole strip is the target, and a
    // block the user folded by hand opens back up when something lands in it.
    DropArea {
        anchors.fill: parent
        enabled: section.effectiveCollapsed
        keys: ["kanban/task"]

        onEntered: {
            section.dropActive = true;
            section.dropIndex = -1;
        }
        onExited: section.dropActive = false
        onDropped: drop => {
            section.dropActive = false;
            if (drop.source && drop.source.columnItem) {
                if (section.collapsed)
                    section.ownerColumn.setSectionCollapsed(section.sectionIndex, false);
                section.acceptDrop(drop.source, 0);
            }
            drop.accept(Qt.MoveAction);
        }
    }

    // ---- menu --------------------------------------------------------------
    PC3.Menu {
        id: secMenu
        PC3.MenuItem {
            text: i18n("Add task")
            icon.name: "list-add"
            onTriggered: section.beginCompose()
        }
        PC3.MenuItem {
            text: i18n("Rename section")
            icon.name: "edit-rename"
            onTriggered: section.startRename()
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: i18n("Move up")
            icon.name: "arrow-up"
            enabled: section.sectionIndex > 0
            onTriggered: section.ownerColumn.moveSection(section.sectionIndex,
                                                         section.sectionIndex - 1)
        }
        PC3.MenuItem {
            text: i18n("Move down")
            icon.name: "arrow-down"
            enabled: section.sectionIndex < section.ownerColumn.sectionCount - 1
            onTriggered: section.ownerColumn.moveSection(section.sectionIndex,
                                                         section.sectionIndex + 1)
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: i18n("Add section below")
            icon.name: "list-add"
            onTriggered: section.ownerColumn.beginAddSection(section.sectionIndex + 1)
        }
        PC3.MenuItem {
            text: i18n("Clear completed")
            icon.name: "edit-clear-all"
            enabled: tasksModel.count - section.openTasks > 0
            onTriggered: section.clearCompleted()
        }
        PC3.MenuItem {
            // Never destroys cards: they join the neighbouring block.
            text: i18n("Delete section")
            icon.name: "edit-delete"
            enabled: section.ownerColumn.sectionCount > 1
            onTriggered: section.ownerColumn.removeSection(section.sectionIndex)
        }
    }

    function startRename() {
        sectionRename.text = section.sectionName;
        sectionRename.visible = true;
        sectionRename.forceActiveFocus();
        sectionRename.selectAll();
    }

    function commitRename() {
        if (!sectionRename.visible) return;
        sectionRename.visible = false;
        var t = sectionRename.text.trim();
        if (t.length > 0 && t !== section.sectionName)
            ownerColumn.renameSection(section.sectionIndex, t);
    }
}
