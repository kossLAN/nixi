pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets
import qs.notifications

StyledMouseArea {
    id: root
    visible: ShellSettings.settings.debugEnabled

    // Have to use a Component to make them dynamically otherwise we just make
    // mutiple toasts for one backer
    onClicked: Notifications.createNotification(notification)

    IconImage {
        id: icon
        anchors.fill: parent
        source: Quickshell.iconPath("settings")
    }

    property Component notification: NotificationBacker {
        id: toast

        summary: "Lorem Ipsum is simply dummy text of the printing and typesetting industry"
        iconSource: Quickshell.iconPath("settings")

        body: Text {
            color: ShellSettings.colors.active.text.darker(1.25)
            font.pixelSize: 12
            font.weight: Font.Normal
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            maximumLineCount: 4

            text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
        }

        icon: IconImage {
            source: Quickshell.iconPath("settings")
            implicitSize: 36
        }

        buttons: IconButton {
            color: ShellSettings.colors.active.light
            source: Quickshell.iconPath("window-close")
            implicitSize: 16
            onClicked: toast.hide()
        }
    }
}
