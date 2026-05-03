import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
    }

    Connections {
        target: server

        // Need to set to tracked otherwise we won't get trackedNotifications
        function onNotification(notification) {
            notification.tracked = true;
        }
    }

    // Insert application notifications into our system
    Instantiator {
        model: ScriptModel {
            values: [...server.trackedNotifications.values]
        }

        delegate: ApplicationNotificationBacker {
            id: backer

            required property Notification modelData

            serverNotification: modelData

            // When our UI triggers discard, dismiss the server notification
            // This will cause the Instantiator to remove this delegate
            onDiscarded: serverNotification.dismiss()
        }

        onObjectAdded: (index, object) => Notifications.addNotification(object)
        onObjectRemoved: (index, object) => Notifications.removeNotification(object)
    }
}
