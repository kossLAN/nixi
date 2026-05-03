pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs
import qs.widgets
import qs.launcher.settings
import qs.launcher.chat

Singleton {
    property alias launcherOpen: persist.launcherOpen
    property alias chatFloatingOpen: persist.chatFloatingOpen

    PersistentProperties {
        id: persist

        property bool launcherOpen: false
        property bool chatFloatingOpen: false
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            persist.launcherOpen = true;
        }

        function close(): void {
            persist.launcherOpen = false;
        }

        function toggle(): void {
            persist.launcherOpen = !persist.launcherOpen;
        }
    }

    LazyLoader {
        active: persist.launcherOpen

        PanelWindow {
            id: panel
            visible: true
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: "shell:launcher"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            RectangularShadow {
                anchors.fill: view
                radius: view.radius
                blur: 16
                spread: 2
                offset: Qt.vector2d(0, 4)
                color: Qt.rgba(0, 0, 0, 0.5)
            }

            StyledRectangle {
                id: view
                clip: true
                implicitWidth: manager.implicitWidth
                implicitHeight: manager.implicitHeight

                x: Math.max(0, Math.min(manager.centerX - (view.width / 2), panel.width - view.width))

                y: {
                    let pos;
                    if (ShellSettings.sizing.launcherPosition.y === -1)
                        pos = (panel.screen.height / 2) - 325;
                    else
                        pos = ShellSettings.sizing.launcherPosition.y;

                    return Math.max(0, Math.min(pos, panel.height - view.height));
                }

                function setPositon() {
                    view.x = Math.max(0, Math.min(view.x, panel.width - view.width));
                    view.y = Math.max(0, Math.min(view.y, panel.height - view.height));

                    manager.centerX = view.x + view.width / 2;

                    ShellSettings.sizing.launcherPosition.centerX = manager.centerX;
                    ShellSettings.sizing.launcherPosition.y = view.y;

                    view.x = Qt.binding(() => Math.max(0, Math.min(manager.centerX - (view.width / 2), panel.width - view.width)));
                }

                Item {
                    id: dragArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 8
                    z: 1

                    HoverHandler {
                        cursorShape: Qt.SizeAllCursor
                    }

                    DragHandler {
                        id: handler
                        target: view

                        xAxis.minimum: 0
                        xAxis.maximum: panel.width - view.width
                        yAxis.minimum: 0
                        yAxis.maximum: panel.height - view.height

                        onActiveChanged: {
                            if (!active) {
                                view.setPositon();
                            }
                        }
                    }
                }

                LauncherManager {
                    id: manager

                    property real centerX: { 
                        if (ShellSettings.sizing.launcherPosition.centerX === -1)
                            return panel.screen.width / 2 
                        else 
                            return ShellSettings.sizing.launcherPosition.centerX
                    }

                    model: [
                        ApplicationLauncher {
                            onAccepted: persist.launcherOpen = false
                        },
                        Chat {},
                        Settings {}
                    ]

                    onCurrentIndexChanged: {
                        centerX = view.x + view.width / 2;
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        persist.launcherOpen = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        manager.currentIndex = (manager.currentIndex + 1) % manager.enabledModel.length;
                        event.accepted = true;
                    }
                }

                Behavior on implicitWidth {
                    enabled: manager.currentItem.animate

                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on implicitHeight {
                    enabled: manager.currentItem.animate

                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    LazyLoader {
        active: persist.chatFloatingOpen

        FloatingWindow {
            id: chatWindow

            visible: true
            color: "transparent"
            title: "Nixi Chat"
            minimumSize: Qt.size(400, 300)
            implicitWidth: ShellSettings.sizing.chatSize.width
            implicitHeight: ShellSettings.sizing.chatSize.height

            onVisibleChanged: {
                if (!visible)
                    persist.chatFloatingOpen = false;
            }

            StyledRectangle {
                color: ShellSettings.colors.active.window
                clip: true
                anchors.fill: parent

                ChatManager {
                    floating: true
                    anchors.fill: parent
                }
            }
        }
    }

    function openFloatingChat(): void {
        persist.chatFloatingOpen = true;
        persist.launcherOpen = false;
    }

    function closeFloatingChat(): void {
        persist.chatFloatingOpen = false;
    }

    function init() {
    }
}
