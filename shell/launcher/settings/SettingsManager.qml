pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets

Item {
    id: root

    required property list<SettingsBacker> model

    property list<SettingsBacker> enabledModel: model.filter(x => x.enabled)

    property alias currentIndex: switcher.currentIndex

    RowLayout {
        spacing: 0
        anchors.fill: parent

        ListView {
            id: switcher
            spacing: 6
            interactive: false

            Layout.preferredWidth: 140
            Layout.fillHeight: true
            Layout.margins: 8

            model: root.enabledModel.map(x => ({
                        icon: x.icon,
                        label: x.label
                    }))

            delegate: StyledMouseArea {
                id: delegateButton

                required property var modelData
                required property var index

                radius: 6
                implicitWidth: ListView.view.width
                implicitHeight: 28
                color: delegateButton.ListView.isCurrentItem ? ShellSettings.colors.inactive.highlight : "transparent"
                hoverColor: ShellSettings.colors.active.highlight

                onClicked: root.currentIndex = index

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 6

                    IconImage {
                        source: Quickshell.iconPath(delegateButton.modelData.icon)
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                    }

                    StyledText {
                        text: delegateButton.modelData.label
                        font.pointSize: 9
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Separator {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledText {
                text: root.enabledModel[root.currentIndex].summary
                font.pointSize: 9
                font.weight: Font.Medium
                Layout.margins: 12
            }

            // Separator {
            //     Layout.fillWidth: true
            //     Layout.preferredHeight: 1
            // }

            Loader {
                id: wrapper
                active: root.enabledModel[root.currentIndex].content
                sourceComponent: root.enabledModel[root.currentIndex].content

                Layout.fillWidth: true
                Layout.fillHeight: true

                onSourceComponentChanged: opacityAnim.restart()

                NumberAnimation {
                    id: opacityAnim
                    target: wrapper
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
