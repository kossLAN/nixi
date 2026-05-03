pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets

Item {
    id: root

    required property string iconSource
    property string badgeIconSource: ""
    property bool badgeIconVisible: false

    visible: iconSource !== ""
    width: 36
    height: 36

    Image {
        id: mainImage
        fillMode: Image.PreserveAspectCrop
        anchors.fill: parent
        source: root.iconSource

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: mainImage.width
                height: mainImage.height
                radius: mainImage.width / 2
            }
        }
    }

    IconImage {
        visible: root.badgeIconVisible && root.badgeIconSource !== ""
        width: 18
        height: 18
        anchors.right: parent.right
        anchors.rightMargin: -4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4
        source: root.badgeIconSource
    }
}
