import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

import "dates.js" as Dates

// Where a card's deadline is chosen: a row of the days people actually pick, a
// month grid for the rest, and one button to take the deadline away again.
PC3.Popup {
    id: picker

    // The list's colour, so the picker belongs to the card it opened from.
    property color accent: Kirigami.Theme.highlightColor
    // "YYYY-MM-DD", or "" for a card with no deadline yet.
    property string selected: ""

    // Where the picker sits, both in the coordinates of the item it hangs off:
    // the rectangle it opens against, and the room it may take.
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    property rect boundsRect: Qt.rect(0, 0, 0, 0)

    signal picked(string iso)
    signal cleared()

    // The month on screen. Held apart from the selection so paging through the
    // calendar never changes the card.
    property int shownYear: Dates.today().getFullYear()
    property int shownMonth: Dates.today().getMonth()

    // `locale` itself is final on Popup, hence the name.
    readonly property var loc: Qt.locale()
    readonly property real cell: Math.round(Kirigami.Units.gridUnit * 1.9)
    readonly property string todayIso: Dates.toIso(Dates.today())

    modal: false
    focus: true
    padding: Kirigami.Units.smallSpacing * 1.5
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    // Opens on the month the card is already due in, so correcting a date never
    // starts by paging back to it.
    function showAt(iso, anchor, bounds) {
        var d = Dates.parse(iso);
        picker.selected = d ? iso.trim() : "";
        var anchorDate = d ? d : Dates.today();
        picker.shownYear = anchorDate.getFullYear();
        picker.shownMonth = anchorDate.getMonth();
        picker.anchorRect = anchor;
        picker.boundsRect = bounds;
        picker.place();
        picker.open();
    }

    // Below the anchor, above it when the bottom is out of room, and shoved
    // back inside `boundsRect` when neither side fits: a calendar hanging off
    // the screen behind a panel is no calendar at all.
    function place() {
        var b = picker.boundsRect;
        if (b.width <= 0 || b.height <= 0)
            return;

        var a = picker.anchorRect;
        var gap = Kirigami.Units.smallSpacing;
        var w = picker.implicitWidth;
        var h = picker.implicitHeight;

        var below = a.y + a.height + gap;
        var above = a.y - gap - h;
        picker.y = below + h <= b.y + b.height ? below
                 : (above >= b.y ? above
                                 : Math.max(b.y, b.y + b.height - h));
        picker.x = Math.max(b.x, Math.min(a.x, b.x + b.width - w));
    }

    // The popup's size settles a frame after the "No deadline" button comes or
    // goes, so place again on the size it ended up with rather than trusting
    // the one read before it was on screen.
    onImplicitHeightChanged: if (picker.visible) picker.place()
    onImplicitWidthChanged: if (picker.visible) picker.place()
    onOpened: picker.place()

    function stepMonth(delta) {
        var d = new Date(picker.shownYear, picker.shownMonth + delta, 1);
        picker.shownYear = d.getFullYear();
        picker.shownMonth = d.getMonth();
    }

    function choose(iso) {
        picker.selected = iso;
        picker.picked(iso);
        picker.close();
    }

    function clear() {
        picker.selected = "";
        picker.cleared();
        picker.close();
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // quick rows -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(Kirigami.Units.smallSpacing / 2)

            Repeater {
                model: [
                    { label: i18n("Today"),    days: 0 },
                    { label: i18n("Tomorrow"), days: 1 },
                    { label: i18n("Next week"), days: 7 }
                ]
                delegate: PC3.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    flat: true
                    text: modelData.label
                    font: Kirigami.Theme.smallFont
                    onClicked: picker.choose(Dates.shift(modelData.days))
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        }

        // month header -----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            PC3.ToolButton {
                icon.name: "arrow-left"
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
                onClicked: picker.stepMonth(-1)
            }

            PC3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.weight: Font.DemiBold
                text: picker.loc.standaloneMonthName(picker.shownMonth, Locale.LongFormat)
                      + " " + picker.shownYear

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // Lost in the calendar: one click is back to this month.
                    onClicked: {
                        var t = Dates.today();
                        picker.shownYear = t.getFullYear();
                        picker.shownMonth = t.getMonth();
                    }
                }
            }

            PC3.ToolButton {
                icon.name: "arrow-right"
                flat: true
                display: PC3.AbstractButton.IconOnly
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: Kirigami.Units.iconSizes.medium
                onClicked: picker.stepMonth(1)
            }
        }

        // weekday header ---------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: 7
                delegate: PC3.Label {
                    required property int index
                    Layout.preferredWidth: picker.cell
                    horizontalAlignment: Text.AlignHCenter
                    font: Kirigami.Theme.smallFont
                    opacity: 0.5
                    text: picker.loc.dayName((picker.loc.firstDayOfWeek + index) % 7,
                                                Locale.NarrowFormat)
                }
            }
        }

        // month grid -------------------------------------------------------
        Grid {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            rows: 6

            // Six rows always: a calendar that changes height as you page
            // through it drags the whole popup around with it.
            readonly property date start: Dates.gridStart(picker.shownYear, picker.shownMonth,
                                                          picker.loc.firstDayOfWeek)

            Repeater {
                model: 42

                delegate: Item {
                    id: dayCell

                    required property int index
                    readonly property date cellDate: Dates.addDays(grid.start, index)
                    readonly property string iso: Dates.toIso(cellDate)
                    readonly property bool inMonth: cellDate.getMonth() === picker.shownMonth
                    readonly property bool isToday: iso === picker.todayIso
                    readonly property bool isSelected: picker.selected.length > 0
                                                       && iso === picker.selected

                    width: picker.cell
                    height: picker.cell

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Kirigami.Units.cornerRadius
                        color: dayCell.isSelected ? picker.accent
                             : (dayArea.containsMouse ? Qt.alpha(picker.accent, 0.18)
                                                      : "transparent")
                        // Today is a ring rather than a fill, so it never reads
                        // as the day the card is due.
                        border.width: dayCell.isToday && !dayCell.isSelected ? 1 : 0
                        border.color: Qt.alpha(picker.accent, 0.7)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        PC3.Label {
                            anchors.centerIn: parent
                            text: dayCell.cellDate.getDate()
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.weight: dayCell.isToday ? Font.DemiBold : Font.Normal
                            color: dayCell.isSelected ? "white" : Kirigami.Theme.textColor
                            opacity: dayCell.inMonth ? 1.0 : 0.35
                        }
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.choose(dayCell.iso)
                    }
                }
            }
        }

        PC3.Button {
            Layout.fillWidth: true
            flat: true
            visible: picker.selected.length > 0
            icon.name: "edit-clear"
            text: i18n("No deadline")
            font: Kirigami.Theme.smallFont
            onClicked: picker.clear()
        }
    }
}
