import QtQuick
import Quickshell

Scope {
    id: root

    property int notificationId

    property string summary: ""
    property Component body: null
    property Component icon: null
    property Component buttons: null
    property string iconSource: ""
    property string badgeIconSource: ""
    property bool badgeIconVisible: false
    property var timeTracked: new Date()

    property bool showOnFullscreen: false
    property bool hovered: false
    property bool hidden: false
    property bool ownedByNotificationCenter: false

    // discard: request to discard (starts animation if visible)
    // discarded: discard complete (triggers removal)
    // hide: request to hide toast (move to notification center)
    signal discard
    signal discarded
    signal hide

    // For hidden notifications (no toast animation), immediately complete discard
    onDiscard: {
        if (hidden) {
            discarded();
        }
    }
}
