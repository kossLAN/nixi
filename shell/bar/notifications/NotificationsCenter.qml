pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.widgets
import qs.bar
import qs.notifications

IconButton {
    id: root
    onClicked: Notifications.centerOpen = !Notifications.centerOpen
    padding: 1

    source: {
        if (Notifications.hasHiddenNotifications)
            return Quickshell.iconPath("notification-active");

        return Quickshell.iconPath("notification-inactive");
    }

    required property var bar

    property PopupItem menu: PopupItem {
        id: menu

        owner: root
        popup: root.bar.popup
        show: Notifications.centerOpen
        onClosed: Notifications.centerOpen = false
        implicitWidth: 525
        fullHeight: true
        expand: Popup.ExpandRight

        NotificationsViewer {
            menu: menu
            anchors.fill: parent
        }
    }
}
