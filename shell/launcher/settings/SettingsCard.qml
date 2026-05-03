import QtQuick
import QtQuick.Layouts

import qs.widgets

Item {
    id: root

    property string title: ""
    property string summary: ""

    property Component controls: Item {}
    property real controlWidth: 140

    RowLayout {
        anchors.fill: parent

        ColumnLayout {
            spacing: 2

            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                text: root.title
                font.pointSize: 9
            }

            StyledText {
                text: root.summary
                font.pointSize: 9
                opacity: 0.7
            }
        }

        RowLayout {
            spacing: 0
            Layout.preferredWidth: Math.max(root.controlWidth, controlsLoader.item?.width ?? controlsLoader.implicitWidth)
            Layout.alignment: Qt.AlignVCenter

            Item {
                Layout.fillWidth: true
            }

            Loader {
                id: controlsLoader
                active: root.controls
                sourceComponent: root.controls

                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
