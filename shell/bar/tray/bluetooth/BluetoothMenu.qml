pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth

import qs.widgets
import qs.bar.tray
import qs

TrayBacker {
    id: root

    trayId: "bluetooth"
    enabled: ShellSettings.settings.bluetoothEnabled

    icon: {
        if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) {
            return Quickshell.iconPath("bluetooth-online");
        } else {
            return Quickshell.iconPath("bluetooth-offline");
        }
    }

    button: StyledMouseArea {
        onClicked: root.clicked()

        IconImage {
            source: root.icon

            anchors {
                fill: parent
                margins: 1
            }
        }
    }

    menu: Item {
        id: menu
        implicitWidth: 300
        implicitHeight: container.implicitHeight + (2 * container.anchors.margins)

        property var entryHeight: 35

        ColumnLayout {
            id: container
            spacing: 2

            anchors {
                fill: parent
                margins: 4
            }

            BluetoothCard {
                adapter: Bluetooth.defaultAdapter

                Layout.fillWidth: true
                Layout.preferredHeight: menu.entryHeight
            }

            StyledListView {
                id: appList
                spacing: 2
                model: Bluetooth.devices
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: {
                    const entryHeight = Math.min(8, Bluetooth.devices && Bluetooth.devices.values ? Bluetooth.devices.values.length : 0);

                    return entryHeight * (menu.entryHeight + appList.spacing);
                }

                delegate: BluetoothCard {
                    device: modelData
                    width: ListView.view.width
                    height: menu.entryHeight

                    required property BluetoothDevice modelData
                }
            }
        }
    }
}
