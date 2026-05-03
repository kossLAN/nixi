pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

import qs.widgets
import qs.bar.tray

TrayBacker {
    id: root

    required property SystemTrayItem item

    enabled: item !== null
    trayId: "systray-" + (item?.id ?? "unknown")
    icon: item?.icon ?? ""

    button: StyledMouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: event => {
            event.accepted = true;

            if (event.button == Qt.LeftButton && root.item?.hasMenu) {
                root.clicked();
            } else if (event.button == Qt.RightButton) {
                root.item?.activate();
            } else if (event.button == Qt.MiddleButton) {
                root.item?.secondaryActivate();
            }
        }

        IconImage {
            source: root.icon

            anchors {
                fill: parent
                margins: 2
            }
        }
    }

    menu: Item {
        id: menuContainer
        implicitWidth: menuContentLoader.width + (2 * 4)
        implicitHeight: menuContentLoader.height + (2 * 4)

        Loader {
            id: menuContentLoader
            anchors.centerIn: parent
            active: true

            sourceComponent: MenuView {
                menu: root.item?.menu ?? null
            }
        }
    }
}
