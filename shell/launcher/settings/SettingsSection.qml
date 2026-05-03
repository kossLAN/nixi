import QtQuick
import QtQuick.Layouts

import qs
import qs.widgets

StyledRectangle {
    id: root

    default property alias contentData: body.data
    property string title: ""

    radius: 6
    color: ShellSettings.colors.active.base
    clip: true
    implicitHeight: content.implicitHeight + 16

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight

    ColumnLayout {
        id: content
        spacing: 6

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }

        StyledText {
            text: root.title
            font.pointSize: 10
            font.bold: true
            opacity: 0.9
            visible: text !== ""

            Layout.fillWidth: true
            Layout.preferredHeight: visible ? contentHeight : 0
        }

        ColumnLayout {
            id: body
            spacing: 2

            Layout.fillWidth: true
        }
    }
}
