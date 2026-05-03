pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import QtQuick.Effects

import qs.widgets

Scope {
    id: root

    required property var bar

    property real gaps: 5

    property Item parentItem
    property PopupItem activeItem
    property PopupItem lastActiveItem

    property PopupItem shownItem: activeItem ?? lastActiveItem

    signal popupOpened
    signal popupClosed

    onActiveItemChanged: {
        if (activeItem != null) {
            activeItem.targetVisible = true;

            if (parentItem) {
                activeItem.parent = parentItem;
            }
        }

        if (lastActiveItem != null && lastActiveItem != activeItem) {
            lastActiveItem.targetVisible = false;
        }

        if (activeItem != null) {
            lastActiveItem = activeItem;
        }
    }

    function setItem(item: PopupItem) {
        activeItem = item;
    }

    function removeItem(item: PopupItem) {
        if (activeItem == item) {
            activeItem = null;
        }
    }

    function onHidden(item: PopupItem) {
        if (item == lastActiveItem) {
            lastActiveItem = null;
        }
    }

    property real scaleMul: lastActiveItem && lastActiveItem.targetVisible ? 1 : 0
    property int expand: Popup.ExpandTop
    property real cachedWidth: 0
    property real cachedHeight: 0
    property real cachedX: 0
    property real cachedOriginX: 0

    property real animationDuration: 200

    enum Expand {
        ExpandTop,
        ExpandLeft,
        ExpandRight
    }

    Behavior on cachedWidth {
        enabled: root.shownItem?.animate ?? false

        SmoothedAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on cachedHeight {
        enabled: root.shownItem?.animate ?? false

        SmoothedAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on cachedX {
        enabled: root.shownItem?.animate ?? false

        SmoothedAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scaleMul {
        SmoothedAnimation {
            velocity: 5
        }
    }

    LazyLoader {
        id: popupLoader
        active: root.shownItem != null || root.scaleMul > 0

        PopupWindow {
            id: popup
            visible: true
            color: "transparent"
            implicitWidth: root.bar.width
            implicitHeight: Math.max(popup.screen.height, parentItem.targetHeight)

            mask: Region {
                item: parentItem
            }

            anchor {
                window: root.bar
                rect: Qt.rect(0, 0, root.bar.width, root.bar.height)
                edges: Edges.Bottom | Edges.Left
                gravity: Edges.Bottom | Edges.Right
                adjustment: PopupAdjustment.None
            }

            HyprlandFocusGrab {
                id: grab
                active: popup.visible
                windows: [popup, root.bar]

                onCleared: {
                    root.shownItem.closed();
                }
            }

            RectangularShadow {
                anchors.fill: parentItem
                radius: backgroundLoader.item.radius ?? 8
                blur: 16
                spread: 2
                offset: Qt.vector2d(0, 4)
                color: Qt.rgba(0, 0, 0, 0.5)
            }

            Item {
                id: parentItem
                clip: true

                x: {
                    if (root.expand === Popup.ExpandRight)
                        return root.cachedX + root.cachedWidth * (1 - root.scaleMul);
                    else if (root.expand === Popup.ExpandLeft)
                        return root.cachedX;
                    else
                        return root.cachedX + root.cachedOriginX * (1 - root.scaleMul);
                }

                y: root.gaps

                width: {
                    if (root.expand !== Popup.ExpandTop)
                        return root.cachedWidth;

                    return root.cachedWidth * root.scaleMul;
                }

                height: {
                    if (root.shownItem?.fullHeight)
                        return root.cachedHeight;

                    return root.cachedHeight * root.scaleMul;
                }

                Loader {
                    id: backgroundLoader
                    anchors.fill: parent
                    sourceComponent: root.shownItem?.backgroundComponent ?? defaultBackground
                }

                Component {
                    id: defaultBackground

                    StyledRectangle {
                        anchors.fill: parent
                    }
                }

                readonly property var targetWidth: root.shownItem?.implicitWidth ?? 0

                readonly property var targetHeight: {
                    if (root.shownItem?.fullHeight) {
                        return popup.screen.height - root.bar.height - (root.gaps * 2);
                    }
                    return root.shownItem?.implicitHeight ?? 0;
                }

                readonly property var targetX: {
                    if (root.shownItem == null) {
                        return 0;
                    }

                    let owner = root.shownItem.owner;
                    let bar = root.bar;
                    let isCentered = root.shownItem.centered;
                    let expand = root.shownItem.expand;
                    let xPos = owner.mapToItem(bar.contentItem, 0, bar.height, owner.width, 0).x;

                    let maxRightEdge = popup.width - targetWidth - root.gaps;

                    if (expand === Popup.ExpandRight) {
                        return maxRightEdge;
                    }

                    if (expand === Popup.ExpandLeft) {
                        return root.gaps;
                    }

                    if (isCentered) {
                        xPos = xPos - (targetWidth / 2) + (owner.width / 2);
                    }

                    return Math.max(root.gaps, Math.min(xPos, maxRightEdge));
                }

                readonly property var targetOriginX: {
                    if (root.shownItem == null) {
                        return 0;
                    }

                    let owner = root.shownItem.owner;
                    let bar = root.bar;
                    let ownerCenterX = owner.mapToItem(bar.contentItem, 0, 0, owner.width, 0).x + (owner.width / 2);

                    return ownerCenterX - targetX;
                }

                onTargetWidthChanged: if (root.shownItem)
                    root.cachedWidth = targetWidth

                onTargetHeightChanged: if (root.shownItem)
                    root.cachedHeight = targetHeight

                onTargetXChanged: if (root.shownItem)
                    root.cachedX = targetX

                onTargetOriginXChanged: if (root.shownItem)
                    root.cachedOriginX = targetOriginX

                Connections {
                    target: root

                    function onShownItemChanged() {
                        if (root.shownItem) {
                            root.expand = root.shownItem.expand;
                        }
                    }
                }

                Component.onCompleted: {
                    root.parentItem = this;
                    root.expand = root.shownItem?.expand ?? Popup.ExpandTop;
                    root.cachedWidth = targetWidth;
                    root.cachedHeight = targetHeight;
                    root.cachedX = targetX;
                    root.cachedOriginX = targetOriginX;

                    if (root.activeItem) {
                        root.activeItem.parent = this;
                        root.popupOpened();
                    }
                }

                Component.onDestruction: {
                    root.popupClosed();
                }
            }
        }
    }
}
