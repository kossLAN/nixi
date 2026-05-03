pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.bar
import qs.notifications

ListView {
    id: root
    spacing: 4

    required property PopupItem menu

    property var animatedSummaries: ({})

    function clearNotifications() {
        for (let i = 0; i < count; i++) {
            itemAtIndex(i)?.discard();
        }
    }

    model: ScriptModel {
        objectProp: "id"
        values: {
            const notifications = [...Notifications.hiddenNotifications];
            const groups = new Map();

            for (const notif of notifications) {
                const key = notif.summary;

                if (!groups.has(key))
                    groups.set(key, []);

                groups.get(key).push(notif);
            }

            return Array.from(groups.values()).map(group => {
                group.sort((a, b) => b.timeTracked - a.timeTracked);

                return {
                    id: group[0].summary,
                    backers: group,
                    latest: group[0],
                    summary: group[0].summary
                };
            });
        }
    }

    delegate: Item {
        id: delegate

        required property var modelData
        required property int index

        property list<NotificationBacker> backers: modelData.backers
        property NotificationBacker latest: modelData.latest
        property string summary: modelData.summary

        function discard() {
            delete root.animatedSummaries[delegate.summary];
            exitAnimation.start();
        }

        implicitWidth: ListView.view.width
        implicitHeight: notificationItem.implicitHeight
        clip: true

        NotificationItem {
            id: notificationItem
            menu: root.menu

            implicitWidth: parent.width

            scale: delegate.contentScale
            transformOrigin: Item.Center

            Behavior on implicitHeight {
                enabled: !entryAnimation.running

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }

            backer: groupBacker
        }

        NotificationBacker {
            id: groupBacker
            summary: delegate.latest?.summary ?? ""
            iconSource: delegate.latest?.iconSource ?? ""
            badgeIconSource: delegate.latest?.badgeIconSource ?? ""
            badgeIconVisible: delegate.latest?.badgeIconVisible ?? false
            icon: groupBacker.iconSource !== "" ? groupIconComponent : (delegate.latest?.icon ?? null)
            timeTracked: delegate.latest?.timeTracked ?? new Date()

            body: bodyComponent

            onDiscard: delegate.discard()
        }

        Component {
            id: groupIconComponent

            NotificationIcon {
                iconSource: groupBacker.iconSource
                badgeIconSource: groupBacker.badgeIconSource
                badgeIconVisible: groupBacker.badgeIconVisible
            }
        }

        Component {
            id: bodyComponent

            ColumnLayout {
                spacing: 4

                Repeater {
                    model: ScriptModel {
                        values: [...delegate.backers]
                    }

                    Loader {
                        required property NotificationBacker modelData

                        active: modelData?.body ?? false
                        sourceComponent: modelData?.body ?? null

                        Layout.fillWidth: true
                    }
                }
            }
        }

        property real contentScale: 1

        Component.onCompleted: {
            if (!root.animatedSummaries[delegate.summary]) {
                root.animatedSummaries[delegate.summary] = true;
                entryAnimation.start();
            }
        }

        NumberAnimation {
            id: entryAnimation
            target: delegate
            property: "contentScale"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: exitAnimation
            target: delegate
            property: "contentScale"
            from: 1
            to: 0
            duration: 200
            easing.type: Easing.InCubic

            onFinished: {
                for (const backer of delegate.backers) {
                    Qt.callLater(backer.discarded);
                }
            }
        }
    }

    removeDisplaced: Transition {
        NumberAnimation {
            property: "y"
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
}
