import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Item {
    id: composer

    property color accent: Kirigami.Theme.highlightColor
    signal submitted(string text)

    // A split list stacks several composers, so there the idle "Add task" row
    // is dropped and the field only takes space while it is in use.
    property bool showIdleHint: true
    property bool active: false

    implicitHeight: active ? field.implicitHeight
                           : (showIdleHint ? hint.implicitHeight : 0)

    Behavior on implicitHeight {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
    }

    function begin() {
        active = true;
        field.forceActiveFocus();
    }

    // idle affordance
    Rectangle {
        id: hint
        anchors.fill: parent
        visible: !composer.active && composer.showIdleHint
        radius: Kirigami.Units.cornerRadius
        implicitHeight: Kirigami.Units.gridUnit * 1.8
        color: hintArea.containsMouse ? Qt.alpha(Kirigami.Theme.textColor, 0.07) : "transparent"
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
                text: i18n("Add task")
                opacity: 0.5
                font: Kirigami.Theme.smallFont
            }
        }

        MouseArea {
            id: hintArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: composer.begin()
        }
    }

    PC3.TextField {
        id: field
        anchors.fill: parent
        visible: composer.active
        placeholderText: i18n("What needs doing?")

        onAccepted: {
            if (text.trim().length > 0) {
                composer.submitted(text);
                text = "";
                // stay open for rapid entry
                forceActiveFocus();
            } else {
                composer.active = false;
            }
        }
        Keys.onEscapePressed: {
            text = "";
            composer.active = false;
        }
        onActiveFocusChanged: {
            if (!activeFocus && composer.active && text.trim().length === 0)
                composer.active = false;
        }
    }
}
