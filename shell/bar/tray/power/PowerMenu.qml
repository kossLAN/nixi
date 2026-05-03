pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower

import qs.widgets
import qs.bar.tray
import qs

TrayBacker {
    id: root

    trayId: "power"
    enabled: UPower.displayDevice.isLaptopBattery
    icon: getIcon(UPower.displayDevice)

    function getIcon(device) {
        if (!device || !device.ready)
            return Quickshell.iconPath("gpm-battery-missing");

        const percentage = device.percentage;
        const isCharging = device.state === 1;

        let iconName = "gpm-battery-";

        if (percentage >= 0.95) {
            iconName += "100";
        } else if (percentage >= 0.75) {
            iconName += "080";
        } else if (percentage >= 0.55) {
            iconName += "060";
        } else if (percentage >= 0.35) {
            iconName += "040";
        } else if (percentage >= 0.15) {
            iconName += "020";
        } else {
            iconName += "000";
        }

        if (isCharging) {
            iconName += "-charging";
        }

        return Quickshell.iconPath(iconName);
    }

    // Filter devices that have batteries (percentage > 0), excluding laptop battery
    property var batteryDevices: {
        let devices = [];

        if (UPower.devices && UPower.devices.values) {
            for (let i = 0; i < UPower.devices.values.length; i++) {
                const dev = UPower.devices.values[i];

                if (dev.percentage > 0 && dev.ready && !dev.isLaptopBattery) {
                    devices.push(dev);
                }
            }
        }

        return devices;
    }

    button: StyledMouseArea {
        onClicked: root.clicked()

        IconImage {
            source: root.getIcon(UPower.displayDevice)

            anchors {
                fill: parent
                margins: 1
            }
        }
    }

    menu: Item {
        id: menu
        implicitWidth: 270
        implicitHeight: container.implicitHeight + (2 * container.anchors.margins)

        property var entryHeight: 38

        ColumnLayout {
            id: container
            spacing: 2

            anchors {
                fill: parent
                margins: 4
            }

            BatteryCard {
                icon: root.getIcon(UPower.displayDevice)
                device: UPower.displayDevice
                visible: UPower.displayDevice.isLaptopBattery
                Layout.fillWidth: true
                Layout.preferredHeight: menu.entryHeight
            }

            StyledListView {
                id: deviceList
                spacing: 2
                model: root.batteryDevices
                clip: true
                visible: root.batteryDevices.length > 0

                Layout.fillWidth: true
                Layout.preferredHeight: {
                    const entryCount = Math.min(6, root.batteryDevices.length);
                    return entryCount * (menu.entryHeight + deviceList.spacing);
                }

                delegate: BatteryCard {
                    icon: root.getIcon(modelData)
                    device: modelData
                    width: ListView.view.width
                    height: menu.entryHeight

                    required property UPowerDevice modelData
                }
            }

            StyledText {
                text: "No battery devices found"
                color: ShellSettings.colors.active.windowText.darker(1.5)
                horizontalAlignment: Text.AlignHCenter
                visible: !UPower.displayDevice.isLaptopBattery && root.batteryDevices.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }
        }
    }
}
