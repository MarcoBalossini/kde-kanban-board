import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

import "dates.js" as Dates

Item {
    id: card

    property var board
    // The section that owns this card. A list that was never split has exactly
    // one, so this is "the list" in the common case.
    property var columnItem
    property int taskIndex: 0

    readonly property bool isDone: model.done === true
    readonly property bool isImportant: model.important === true
    readonly property bool hidden: isDone && board.cfgHideDone
    // A flagged card keeps its list's colours and gains a solid red frame: no
    // list accent is red, so the frame reads from across the board.
    readonly property color highlight: Kirigami.Theme.negativeTextColor
    readonly property bool dragging: content.Drag.active

    // ---- steps ---------------------------------------------------------
    // A card too big for one line is split into steps: its own little
    // checklist, read out of the model so a rebuilt delegate shows the same one.
    readonly property var steps: {
        try {
            return JSON.parse(model.stepsJson || "[]") || [];
        } catch (e) {
            return [];
        }
    }
    readonly property int stepCount: steps.length
    readonly property int stepsDone: {
        var n = 0;
        for (var i = 0; i < steps.length; i++)
            if (steps[i].done) n++;
        return n;
    }
    readonly property bool stepsOpen: model.stepsOpen === true

    // ---- deadline -------------------------------------------------------
    // The day the card is due, "YYYY-MM-DD" or "" — a day, not a minute, so a
    // card is late from the morning after and not from an arbitrary hour.
    readonly property string due: model.due || ""
    readonly property bool hasDue: due.length > 0
    // Days from today; NaN when the card has no deadline. `var`, not `int`: an
    // int property would quietly turn NaN into 0, i.e. into "today".
    readonly property var dueDays: {
        board.todayIso; // recomputed when the day turns over
        return Dates.daysUntil(due);
    }
    // A finished card is never late, however long it sat there.
    readonly property bool overdue: hasDue && !isDone && dueDays < 0
    readonly property bool dueSoon: hasDue && !isDone && (dueDays === 0 || dueDays === 1)
    readonly property color dueColor: overdue ? Kirigami.Theme.negativeTextColor
                                    : (dueSoon ? Kirigami.Theme.neutralTextColor
                                               : Kirigami.Theme.textColor)
    // Steps line up under the card's text, not under its check circle.
    readonly property real textIndent: Kirigami.Units.iconSizes.small
                                       + Kirigami.Units.smallSpacing
    readonly property real stepBox: Math.round(Kirigami.Units.iconSizes.small * 0.75)

    visible: !hidden
    height: hidden ? 0 : content.implicitHeight
    z: dragging ? 10 : 0

    Behavior on height {
        enabled: !card.dragging
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: card.width
        height: card.height
        implicitHeight: body.implicitHeight + 2 * pad
        radius: Kirigami.Units.cornerRadius

        readonly property real pad: board.cfgCompactCards ? Kirigami.Units.smallSpacing
                                                          : Kirigami.Units.smallSpacing * 1.5

        // Cards carry a wash of their list's colour so a card stays recognisable
        // once it has been dragged somewhere else.
        readonly property color baseColor:
            Qt.tint(Kirigami.Theme.backgroundColor,
                    Qt.alpha(columnItem.accent, card.isDone ? 0.05 : 0.11))

        color: hover.hovered && !card.dragging
               ? Qt.tint(baseColor, Qt.alpha(columnItem.accent, 0.09))
               : baseColor
        border.width: card.isImportant ? 2 : 1
        border.color: card.isImportant
                      ? Qt.alpha(card.highlight, card.isDone ? 0.45 : 1.0)
                      : (card.dragging ? Qt.alpha(columnItem.accent, 0.8)
                                       : Qt.alpha(columnItem.accent,
                                                  card.isDone ? 0.15 : 0.28))
        Behavior on border.color { ColorAnimation { duration: 120 } }
        opacity: card.isDone ? 0.6 : 1.0
        scale: card.dragging ? 1.03 : 1.0

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Drag.active: dragArea.drag.active
        Drag.source: card
        Drag.keys: ["kanban/task"]
        Drag.hotSpot.x: content.width / 2
        Drag.hotSpot.y: content.height / 2

        // drop shadow while dragging
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 2
            border.color: Qt.alpha(card.isImportant ? card.highlight
                                                    : columnItem.accent, 0.25)
            visible: card.dragging
        }

        // accent stripe
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            anchors.margins: content.border.width
            width: 3
            radius: width / 2
            color: columnItem.accent
            opacity: card.isDone ? 0.25 : 0.85
        }

        HoverHandler { id: hover }

        // Declared before the content column so the check circle, the text field,
        // the steps and the delete button (later siblings) still get their events
        // first. Filling the whole card leaves no dead zone where a double click
        // could fall through to the containment.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: !editField.visible
            // The card sits in two nested flickables (its section's list and
            // the column's scroller); without this either of them steals the
            // press and the drag never starts.
            preventStealing: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: content
            drag.smoothed: false
            onDoubleClicked: mouse => {
                mouse.accepted = true;
                card.startEdit();
            }
            onReleased: {
                if (content.Drag.active)
                    content.Drag.drop();
            }
        }

        // The card menu is where the step operations live that are not worth a
        // button of their own. A handler rather than a second MouseArea: the
        // drag area above only accepts left clicks, so right ones reach here.
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: cardMenu.popup()
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: content.pad
            spacing: Math.round(Kirigami.Units.smallSpacing / 2)

            RowLayout {
                id: row
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(Kirigami.Units.smallSpacing / 2)
                spacing: Kirigami.Units.smallSpacing

                // check circle
                Item {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 1
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: card.isDone ? columnItem.accent : "transparent"
                        border.width: card.isDone ? 0 : 1.5
                        border.color: check.containsMouse ? columnItem.accent
                                                          : Qt.alpha(Kirigami.Theme.textColor, 0.35)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.7)
                            height: width
                            source: "checkmark"
                            color: "white"
                            isMask: true
                            visible: card.isDone
                        }
                    }
                    MouseArea {
                        id: check
                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: columnItem.toggleDone(card.taskIndex)
                    }
                }

                PC3.Label {
                    id: label
                    visible: !editField.visible
                    Layout.fillWidth: true
                    text: model.text
                    wrapMode: Text.Wrap
                    maximumLineCount: board.cfgCompactCards ? 2 : 6
                    elide: Text.ElideRight
                    font.strikeout: card.isDone && board.cfgStrikeDone
                    opacity: card.isDone ? 0.75 : 1.0
                }

                PC3.TextField {
                    id: editField
                    visible: false
                    Layout.fillWidth: true
                    onAccepted: card.commitEdit()
                    onActiveFocusChanged: if (!activeFocus && visible) card.commitEdit()
                    Keys.onEscapePressed: visible = false
                }

                // deadline ------------------------------------------------
                // Rides on the card's own line rather than under it: a date is
                // part of what the card says, and a second line for three words
                // costs more room than the board has to give.
                Rectangle {
                    id: duePill
                    visible: card.hasDue && !editField.visible
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: dueRow.implicitWidth + Kirigami.Units.smallSpacing * 1.5
                    implicitHeight: dueRow.implicitHeight
                                    + Math.round(Kirigami.Units.smallSpacing / 2)
                    radius: height / 2
                    color: Qt.alpha(card.dueColor, dueArea.containsMouse ? 0.26 : 0.14)
                    border.width: 1
                    border.color: Qt.alpha(card.dueColor, card.overdue ? 0.7 : 0.28)
                    opacity: card.isDone ? 0.55 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: dueRow
                        anchors.centerIn: parent
                        spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                        Kirigami.Icon {
                            source: card.overdue ? "appointment-missed"
                                  : (card.dueSoon ? "appointment-soon" : "view-calendar")
                            implicitWidth: card.stepBox
                            implicitHeight: card.stepBox
                            isMask: true
                            color: card.dueColor
                        }
                        PC3.Label {
                            text: card.dueLabel()
                            font: Kirigami.Theme.smallFont
                            color: card.dueColor
                        }
                    }

                    MouseArea {
                        id: dueArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pickDue()
                    }
                }

                // Kept as a bare icon rather than a ToolButton so the star can be
                // tinted: a symbolic icon in a flat button ignores icon.color on
                // some themes.
                Item {
                    Layout.alignment: Qt.AlignTop
                    visible: (hover.hovered || card.isImportant) && !editField.visible
                    implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    implicitHeight: implicitWidth

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: card.isImportant ? "starred-symbolic" : "non-starred-symbolic"
                        isMask: true
                        color: card.isImportant ? card.highlight : Kirigami.Theme.textColor
                        opacity: card.isImportant ? (card.isDone ? 0.55 : 1.0)
                                                  : (star.containsMouse ? 0.8 : 0.45)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: star
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: columnItem.toggleImportant(card.taskIndex)
                    }
                }

                // A card with no deadline has no chip to click, so the first one
                // is set from here rather than out of the menu alone. Once the
                // chip is there it takes the job back, and the row keeps a slot.
                PC3.ToolButton {
                    icon.name: "view-calendar"
                    flat: true
                    display: PC3.AbstractButton.IconOnly
                    visible: hover.hovered && !card.hasDue && !editField.visible
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    implicitHeight: implicitWidth
                    opacity: 0.7
                    onClicked: card.pickDue()
                }

                PC3.ToolButton {
                    icon.name: "view-list-details"
                    flat: true
                    display: PC3.AbstractButton.IconOnly
                    visible: hover.hovered && !editField.visible
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    implicitHeight: implicitWidth
                    opacity: 0.7
                    onClicked: card.beginAddStep()
                }

                PC3.ToolButton {
                    icon.name: "edit-delete-remove"
                    flat: true
                    display: PC3.AbstractButton.IconOnly
                    visible: hover.hovered && !editField.visible
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    implicitHeight: implicitWidth
                    opacity: 0.7
                    onClicked: columnItem.removeTask(card.taskIndex)
                }
            }

            // progress strip ---------------------------------------------
            // Everything a folded card has to say about its steps: how far it
            // has got, and that clicking here opens them.
            Item {
                id: progress
                visible: card.stepCount > 0 && !editField.visible
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(Kirigami.Units.smallSpacing / 2) + card.textIndent
                Layout.topMargin: Math.round(Kirigami.Units.smallSpacing / 2)
                implicitHeight: progressRow.implicitHeight

                RowLayout {
                    id: progressRow
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: card.stepsOpen ? "arrow-down" : "arrow-right"
                        implicitWidth: card.stepBox
                        implicitHeight: card.stepBox
                        isMask: true
                        color: Kirigami.Theme.textColor
                        opacity: progressHover.hovered ? 0.85 : 0.45
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 3
                        radius: height / 2
                        color: Qt.alpha(columnItem.accent, 0.20)

                        Rectangle {
                            width: parent.width * (card.stepCount > 0
                                                   ? card.stepsDone / card.stepCount : 0)
                            height: parent.height
                            radius: parent.radius
                            color: columnItem.accent
                            opacity: card.isDone ? 0.5 : 0.9
                            Behavior on width {
                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    PC3.Label {
                        text: card.stepsDone + "/" + card.stepCount
                        font: Kirigami.Theme.smallFont
                        opacity: 0.55
                    }
                }

                HoverHandler { id: progressHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleSteps()
                }
            }

            // steps ------------------------------------------------------
            ColumnLayout {
                id: stepList
                visible: card.stepsOpen && !editField.visible
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(Kirigami.Units.smallSpacing / 2) + card.textIndent
                spacing: Math.round(Kirigami.Units.smallSpacing / 2)

                Repeater {
                    model: card.steps

                    // Required properties, not the implicit ones: this delegate
                    // lives inside the card's own delegate, and a bare `index`
                    // would be either row's, depending on the day.
                    delegate: Item {
                        id: stepRow

                        required property int index
                        required property var modelData
                        readonly property bool stepDone: modelData.done === true

                        Layout.fillWidth: true
                        implicitHeight: stepLayout.implicitHeight

                        HoverHandler { id: stepHover }

                        RowLayout {
                            id: stepLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: Kirigami.Units.smallSpacing

                            Item {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                implicitWidth: card.stepBox
                                implicitHeight: card.stepBox

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: stepRow.stepDone ? columnItem.accent : "transparent"
                                    border.width: stepRow.stepDone ? 0 : 1.5
                                    border.color: stepCheck.containsMouse
                                                  ? columnItem.accent
                                                  : Qt.alpha(Kirigami.Theme.textColor, 0.30)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        width: Math.round(parent.width * 0.7)
                                        height: width
                                        source: "checkmark"
                                        color: "white"
                                        isMask: true
                                        visible: stepRow.stepDone
                                    }
                                }
                                MouseArea {
                                    id: stepCheck
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: columnItem.toggleStep(card.taskIndex, stepRow.index)
                                }
                            }

                            PC3.Label {
                                visible: !stepEdit.visible
                                Layout.fillWidth: true
                                text: stepRow.modelData.text
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.strikeout: stepRow.stepDone && board.cfgStrikeDone
                                opacity: stepRow.stepDone ? 0.55 : 0.85

                                MouseArea {
                                    anchors.fill: parent
                                    onPressed: mouse => mouse.accepted = true
                                    onDoubleClicked: mouse => {
                                        mouse.accepted = true;
                                        stepRow.startEdit();
                                    }
                                }
                            }

                            PC3.TextField {
                                id: stepEdit
                                visible: false
                                Layout.fillWidth: true
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                onAccepted: stepRow.commitEdit()
                                onActiveFocusChanged: if (!activeFocus && visible) stepRow.commitEdit()
                                Keys.onEscapePressed: visible = false
                            }

                            PC3.ToolButton {
                                icon.name: "edit-delete-remove"
                                icon.width: card.stepBox
                                icon.height: card.stepBox
                                flat: true
                                display: PC3.AbstractButton.IconOnly
                                visible: stepHover.hovered && !stepEdit.visible
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: card.stepBox + Kirigami.Units.smallSpacing
                                implicitHeight: implicitWidth
                                opacity: 0.6
                                onClicked: columnItem.removeStep(card.taskIndex, stepRow.index)
                            }
                        }

                        function startEdit() {
                            stepEdit.text = stepRow.modelData.text;
                            stepEdit.visible = true;
                            stepEdit.forceActiveFocus();
                            stepEdit.selectAll();
                        }

                        // Clearing the text deletes the step, exactly as it does
                        // on a card.
                        function commitEdit() {
                            if (!stepEdit.visible) return;
                            stepEdit.visible = false;
                            columnItem.setStepText(card.taskIndex, stepRow.index, stepEdit.text);
                        }
                    }
                }

                TaskComposer {
                    id: stepComposer
                    Layout.fillWidth: true
                    accent: columnItem.accent
                    hintText: i18n("Add step")
                    fieldPlaceholder: i18n("Next step")
                    hintHeight: Kirigami.Units.gridUnit * 1.3
                    onSubmitted: text => columnItem.addStep(card.taskIndex, text)
                }
            }
        }

        states: State {
            when: dragArea.drag.active
            ParentChange { target: content; parent: board.dragLayer }
            AnchorChanges {
                target: content
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: undefined
            }
        }
    }

    PC3.Menu {
        id: cardMenu
        PC3.MenuItem {
            text: card.stepCount > 0 ? i18n("Add step") : i18n("Split into steps")
            icon.name: "view-list-details"
            onTriggered: card.beginAddStep()
        }
        PC3.MenuItem {
            text: i18n("Clear finished steps")
            icon.name: "edit-clear-all"
            enabled: card.stepsDone > 0
            onTriggered: columnItem.clearDoneSteps(card.taskIndex)
        }
        PC3.MenuItem {
            // Back to a plain card; the card itself is untouched.
            text: i18n("Remove all steps")
            icon.name: "kt-remove-filters"
            enabled: card.stepCount > 0
            onTriggered: columnItem.clearSteps(card.taskIndex)
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: card.hasDue ? i18n("Change deadline…") : i18n("Set deadline…")
            icon.name: "view-calendar"
            onTriggered: card.pickDue()
        }
        PC3.MenuItem {
            text: i18n("No deadline")
            icon.name: "edit-clear"
            enabled: card.hasDue
            onTriggered: columnItem.clearDue(card.taskIndex)
        }
        PC3.MenuSeparator { }
        PC3.MenuItem {
            text: i18n("Edit")
            icon.name: "edit-rename"
            onTriggered: card.startEdit()
        }
        PC3.MenuItem {
            text: card.isImportant ? i18n("Not important") : i18n("Mark as important")
            icon.name: card.isImportant ? "non-starred-symbolic" : "starred-symbolic"
            onTriggered: columnItem.toggleImportant(card.taskIndex)
        }
        PC3.MenuItem {
            text: i18n("Delete card")
            icon.name: "edit-delete"
            onTriggered: columnItem.removeTask(card.taskIndex)
        }
    }

    // Built the first time a deadline is picked: a month grid standing by on
    // every card of the board would cost far more than the feature is worth.
    Loader {
        id: pickerLoader
        anchors.fill: parent
        active: false

        sourceComponent: DuePicker {
            accent: columnItem.accent
            onPicked: iso => columnItem.setDue(card.taskIndex, iso)
            onCleared: columnItem.clearDue(card.taskIndex)
        }
    }

    // The picker hangs off the card, so it is handed the card's own rectangle
    // and the room it is allowed to use; the flipping and clamping are its own.
    function pickDue() {
        pickerLoader.active = true;
        var picker = pickerLoader.item;
        if (!picker) return;
        picker.showAt(card.due,
                      Qt.rect(0, 0, card.width, card.height),
                      card.popupBounds());
    }

    // The room a popup opened from this card may take, in the card's own
    // coordinates. A desktop widget's window covers the whole screen, panels
    // and all, so the panel-free rect has to be subtracted by hand; a panel
    // applet's popup window has already been placed clear of them.
    function popupBounds() {
        var win = card.Window.window;
        var top = win ? win.contentItem : null;
        if (!top)
            return Qt.rect(0, 0, card.width, card.height);

        var x = 0, y = 0, w = top.width, h = top.height;
        var avail = board.availableScreenRect;
        if (avail && avail.width > 0 && avail.height > 0
                && w >= Screen.width - 1 && h >= Screen.height - 1) {
            x = Math.max(x, avail.x);
            y = Math.max(y, avail.y);
            w = Math.min(top.width, avail.x + avail.width) - x;
            h = Math.min(top.height, avail.y + avail.height) - y;
        }
        var p = card.mapFromItem(top, x, y);
        return Qt.rect(p.x, p.y, w, h);
    }

    // "Today" and "Tomorrow" are what a deadline actually means day to day; a
    // date is only spelled out once it is far enough off to need one.
    function dueLabel() {
        var n = card.dueDays;
        if (isNaN(n)) return "";
        if (n === 0) return i18n("Today");
        if (n === 1) return i18n("Tomorrow");
        if (n === -1) return i18n("Yesterday");
        var d = Dates.parse(card.due);
        if (n > 1 && n < 7) return Qt.formatDate(d, "ddd");
        if (d.getFullYear() === Dates.today().getFullYear())
            return Qt.formatDate(d, "d MMM");
        return Qt.formatDate(d, "d MMM yyyy");
    }

    function startEdit() {
        editField.text = model.text;
        editField.visible = true;
        editField.forceActiveFocus();
        editField.selectAll();
    }

    function commitEdit() {
        if (!editField.visible) return;
        editField.visible = false;
        columnItem.setText(card.taskIndex, editField.text);
    }

    function toggleSteps() {
        columnItem.setStepsOpen(card.taskIndex, !card.stepsOpen);
    }

    // Splitting a card is one gesture: the checklist opens and the field is
    // already waiting for the first step.
    function beginAddStep() {
        if (!card.stepsOpen)
            columnItem.setStepsOpen(card.taskIndex, true);
        Qt.callLater(function() { stepComposer.begin(); });
    }
}
