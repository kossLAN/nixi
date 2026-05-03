import QtQuick
import qs

StyledMouseArea {
    id: root

    property real radius: 6
    property bool checked: false
    property var hoverColor: color.lighter(1.5)
    property var checkedColor: hoverColor
    property var color: ShellSettings.colors.active.button

    StyledRectangle {
        color: root.containsMouse ? root.hoverColor : root.checked ? root.checkedColor : root.color
        radius: root.radius
        anchors.fill: parent
    }
}
