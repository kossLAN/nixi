pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.widgets

Item {
    id: root

    property bool floating: false

    RowLayout {
        // spacing: 8
        spacing: 0
        anchors.fill: parent

        ChatSidebar {
            Layout.fillHeight: true
        }

        ChatWindow {
            floating: root.floating
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
