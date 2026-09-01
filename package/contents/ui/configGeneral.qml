import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_boardTitle: titleField.text
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_showCounts: showCountsBox.checked
    property alias cfg_compactCards: compactBox.checked
    property alias cfg_strikeDone: strikeBox.checked
    property alias cfg_hideDone: hideDoneBox.checked
    property alias cfg_columnWidth: widthSpin.value

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.TextField {
            id: titleField
            Kirigami.FormData.label: i18n("Board name:")
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: i18n("Shown in the tooltip when the board sits in a panel.")
            opacity: 0.6
            font: Kirigami.Theme.smallFont
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: opacitySlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways
            }
            QQC2.Label {
                text: i18n("%1%", Math.round(opacitySlider.value))
                Layout.minimumWidth: fontMetrics.advanceWidth("100%")
                horizontalAlignment: Text.AlignRight
            }
        }

        QQC2.CheckBox {
            id: showCountsBox
            Kirigami.FormData.label: i18n("Lists:")
            text: i18n("Show open task counts")
        }

        QQC2.SpinBox {
            id: widthSpin
            Kirigami.FormData.label: i18n("List width:")
            from: 140
            to: 480
            stepSize: 10
            textFromValue: function(value) { return value + " px"; }
            valueFromText: function(text) { return parseInt(text); }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: compactBox
            Kirigami.FormData.label: i18n("Cards:")
            text: i18n("Compact cards")
        }

        QQC2.CheckBox {
            id: strikeBox
            text: i18n("Strike through completed tasks")
        }

        QQC2.CheckBox {
            id: hideDoneBox
            text: i18n("Hide completed tasks")
        }
    }

    FontMetrics {
        id: fontMetrics
    }
}
