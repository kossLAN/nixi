pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

import qs

NotificationBacker {
    id: root

    required property Notification serverNotification
    property int closeAnimDuration: 10000
    property string notificationImage: {
        if (!root.serverNotification)
            return "";

        if (root.serverNotification.image !== "")
            return root.serverNotification.image;

        if (root.serverNotification.appIcon !== "") {
            if (root.serverNotification.appIcon.startsWith("/") || root.serverNotification.appIcon.startsWith("file://"))
                return root.serverNotification.appIcon;

            return Quickshell.iconPath(root.serverNotification.appIcon);
        }

        return "";
    }
    property string appIconSource: {
        if (!root.serverNotification)
            return "";

        if (root.serverNotification.desktopEntry !== "") {
            const entry = DesktopEntries.byId(root.serverNotification.desktopEntry);

            if (entry?.icon)
                return Quickshell.iconPath(entry.icon);
        }

        if (root.serverNotification.appName !== "") {
            const entry = DesktopEntries.byId(root.serverNotification.appName.toLowerCase());

            if (entry?.icon)
                return Quickshell.iconPath(entry.icon);
        }

        return "";
    }

    summary: serverNotification?.summary ?? ""
    iconSource: notificationImage !== "" ? notificationImage : appIconSource
    badgeIconSource: appIconSource
    badgeIconVisible: serverNotification?.image !== "" ?? false

    RetainableLock {
        object: root.serverNotification
        locked: root.serverNotification !== null
    }

    body: Text {
        visible: root.serverNotification.body != ""
        color: ShellSettings.colors.active.text.darker(1.25)
        font.weight: Font.Normal
        font.pixelSize: 12
        wrapMode: Text.WrapAnywhere
        elide: Text.ElideRight
        maximumLineCount: 6

        text: root.serverNotification.body
    }

    icon: NotificationIcon {
        iconSource: root.iconSource
        badgeIconSource: root.badgeIconSource
        badgeIconVisible: root.badgeIconVisible
    }

    buttons: CloseButton {
        paused: root.hovered
        duration: root.closeAnimDuration
        implicitHeight: 20
        implicitWidth: 20

        onFinished: root.hide()
        onClicked: root.discard()
    }
}
