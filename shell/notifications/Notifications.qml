pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool blockToasts: false
    property alias doNotDisturb: persist.doNotDisturb
    property bool centerOpen: false

    IpcHandler {
        target: "notifications"

        function open(): void {
            root.centerOpen = true;
        }

        function close(): void {
            root.centerOpen = false;
        }

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }
    }

    PersistentProperties {
        id: persist

        property bool doNotDisturb: false
    }

    // Handle discarded signal for all notifications
    // For ApplicationNotificationBackers, this runs after serverNotification.dismiss()
    // which triggers onObjectRemoved, but removeNotification is idempotent
    Instantiator {
        model: [...root.notifications]

        Connections {
            required property NotificationBacker modelData

            target: modelData

            function onDiscarded() {
                root.removeNotification(target);
            }
        }
    }

    property bool hasHiddenNotifications: hiddenNotifications.length != 0

    property list<NotificationBacker> hiddenNotifications: notifications.filter(x => {
        return x?.hidden ?? false;
    })

    property int notificationId: 0

    property list<NotificationBacker> notifications: []

    function createNotification(component, properties) {
        const notification = component.createObject(root, properties ?? {});

        if (!notification) {
            console.error("Notifications: failed to create notification");
            return null;
        }

        notification.ownedByNotificationCenter = true;
        root.addNotification(notification);
        return notification;
    }

    function addNotification(notification: NotificationBacker) {
        if (!notification)
            return;

        notification.notificationId = ++notificationId;
        notifications.push(notification);

        // If we block toasts don't spawn a toast, and set backer to hidden state
        if (root.doNotDisturb || root.blockToasts) {
            notification.hidden = true;
        }
    }

    function removeNotification(notification: NotificationBacker) {
        root.notifications = root.notifications.filter(n => n !== notification);

        if (notification?.ownedByNotificationCenter) {
            notification.ownedByNotificationCenter = false;
            Qt.callLater(() => notification.destroy());
        }
    }

    // Handles the create of application notifications
    ApplicationNotifications {}

    NotificationPanel {
        id: panel
        visible: root.notifications.some(n => !n.hidden) && (!root.blockToasts && !root.doNotDisturb)
    }

    // Needs to be loaded, for notifications to work properly
    function init() {
    }
}
