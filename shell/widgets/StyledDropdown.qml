pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    property color color: ShellSettings.colors.active.button
    property var model: []
    property string currentValue: ""

    property string displayText: {
        for (let i = 0; i < model.length; i++) {
            if (model[i].value === currentValue) {
                return model[i].label;
            }
        }

        return "";
    }

    signal selected(string value)

    property var rootItem: {
        let item = root;

        while (item.parent) {
            item = item.parent;
        }

        return item;
    }

    implicitWidth: 140
    implicitHeight: 28

    StyledRectangle {
        id: button

        color: {
            if (mouseArea.containsMouse)
                return root.color.lighter(1.5);

            return root.color;
        }

        radius: 6
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            StyledText {
                text: root.displayText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ExpandArrow {
                expanded: dropdownOverlay.visible
                animate: false
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (dropdownOverlay.visible) {
                    dropdownOverlay.visible = false;
                } else {
                    let pos = root.mapToItem(root.rootItem, 0, root.height + 4);

                    dropdownOverlay.dropdownX = pos.x;
                    dropdownOverlay.dropdownY = pos.y;
                    dropdownOverlay.visible = true;
                }
            }
        }
    }

    Item {
        id: dropdownOverlay
        parent: root.rootItem
        anchors.fill: parent
        visible: false
        z: 999999

        property real dropdownX: 0
        property real dropdownY: 0

        MouseArea {
            anchors.fill: parent
            onClicked: dropdownOverlay.visible = false
            onWheel: event => event.accepted = true
        }

        StyledRectangle {
            id: dropdown
            radius: 6
            color: root.color
            x: dropdownOverlay.dropdownX
            y: dropdownOverlay.dropdownY
            width: root.width
            height: Math.min(dropdownList.contentHeight + 8, 200)

            ListView {
                id: dropdownList
                anchors.fill: parent
                anchors.margins: 4
                clip: true

                model: root.model

                delegate: Rectangle {
                    id: itemDelegate

                    required property var modelData
                    required property int index

                    width: dropdownList.width
                    height: 28
                    radius: 4
                    color: {
                        if (itemMouse.containsMouse)
                            return ShellSettings.colors.active.highlight;

                        if (modelData.value === root.currentValue)
                            return ShellSettings.colors.inactive.highlight;

                        return "transparent";
                    }

                    StyledText {
                        text: itemDelegate.modelData.label
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        color: ShellSettings.colors.active.text
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selected(itemDelegate.modelData.value);
                            dropdownOverlay.visible = false;
                        }
                    }
                }
            }
        }
    }
}
