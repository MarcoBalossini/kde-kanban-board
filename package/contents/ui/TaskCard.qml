import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

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
        implicitHeight: row.implicitHeight + 2 * pad
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

        // Declared before the content row so the check circle, the text field and
        // the delete button (later siblings) still get their events first. Filling
        // the whole card leaves no dead zone where a double click could fall
        // through to the containment.
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

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: content.pad
            anchors.leftMargin: content.pad + Kirigami.Units.smallSpacing / 2
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
}
