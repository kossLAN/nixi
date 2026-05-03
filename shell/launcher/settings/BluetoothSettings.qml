pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

import qs
import qs.widgets

SettingsBacker {
    icon: "bluetooth-online"

    enabled: ShellSettings.settings.bluetoothEnabled

    summary: "Bluetooth Settings"
    label: "Bluetooth"

    content: Item {
        ColumnLayout {
            spacing: 6

            anchors {
                fill: parent
                margins: 8
            }

            StyledRectangle {
                id: adapterCard
                color: ShellSettings.colors.active.base
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: adapterContent.implicitHeight + 12

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: adapterCard.width
                        height: adapterCard.height
                        radius: adapterCard.radius
                        color: "black"
                    }
                }

                ColumnLayout {
                    id: adapterContent
                    spacing: 6

                    anchors {
                        fill: parent
                        margins: 6
                    }

                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        IconImage {
                            source: {
                                if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) {
                                    return Quickshell.iconPath("bluetooth-online");
                                } else {
                                    return Quickshell.iconPath("bluetooth-offline");
                                }
                            }

                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            StyledText {
                                text: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.name : "No Adapter"
                                font.pointSize: 9
                            }

                            StyledText {
                                text: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.adapterId : "N/A"
                                color: ShellSettings.colors.active.windowText.darker(1.5)
                                font.pointSize: 9
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Scan Button (like bar widget)
                        StyledMouseArea {
                            enabled: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled

                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            onClicked: {
                                if (Bluetooth.defaultAdapter) {
                                    Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
                                }
                            }

                            Timer {
                                id: discoveryTimer
                                interval: 15000
                                running: Bluetooth.defaultAdapter?.discovering ?? false

                                onTriggered: {
                                    if (Bluetooth.defaultAdapter) {
                                        Bluetooth.defaultAdapter.discovering = false;
                                    }
                                }
                            }

                            IconImage {
                                id: searchIcon
                                transformOrigin: Item.Center

                                source: {
                                    if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering) {
                                        return Quickshell.iconPath("view-refresh");
                                    } else {
                                        return Quickshell.iconPath("search");
                                    }
                                }

                                anchors {
                                    fill: parent
                                    margins: 2
                                }

                                NumberAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering
                                    onRunningChanged: {
                                        if (!running)
                                            searchIcon.rotation = 0;
                                    }
                                }
                            }
                        }

                        ToggleSwitch {
                            checked: Bluetooth.defaultAdapter?.enabled ?? false
                            enabled: Bluetooth.defaultAdapter !== null

                            Layout.alignment: Qt.AlignVCenter

                            onCheckedChanged: {
                                if (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled !== checked) {
                                    Bluetooth.defaultAdapter.enabled = checked;
                                }
                            }
                        }
                    }
                }
            }

            // Devices Section Header
            RowLayout {
                spacing: 6

                Layout.fillWidth: true

                StyledText {
                    text: "Devices"
                    font.pointSize: 9
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Bluetooth.devices && Bluetooth.devices.values ? `${Bluetooth.devices.values.length} found` : "0 found"
                    color: ShellSettings.colors.active.windowText.darker(1.5)
                    font.pointSize: 9
                }
            }

            Separator {
                Layout.fillWidth: true
            }

            // Device List
            StyledListView {
                id: deviceList
                model: Bluetooth.devices
                spacing: 4
                clip: true
                visible: Bluetooth.devices && Bluetooth.devices.values && Bluetooth.devices.values.length > 0

                Layout.fillWidth: true
                Layout.fillHeight: true

                delegate: StyledRectangle {
                    id: deviceCard
                    color: ShellSettings.colors.active.base
                    clip: true

                    required property BluetoothDevice modelData
                    property bool expanded: false
                    property int collapsedHeight: 52
                    property int expandedHeight: 56 + dropdownContent.implicitHeight

                    implicitWidth: ListView.view.width
                    implicitHeight: expanded ? expandedHeight : collapsedHeight

                    MouseArea {
                        anchors.fill: parent
                        onClicked: deviceCard.expanded = !deviceCard.expanded
                    }

                    Behavior on implicitHeight {
                        SmoothedAnimation {
                            duration: 200
                        }
                    }

                    RowLayout {
                        id: mainRow
                        spacing: 8
                        height: 36

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 8
                        }

                        IconImage {
                            source: deviceCard.modelData && deviceCard.modelData.icon ? Quickshell.iconPath(deviceCard.modelData.icon) : Quickshell.iconPath("bluetooth-active")

                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }

                        ColumnLayout {
                            spacing: 1

                            Layout.fillWidth: true

                            StyledText {
                                text: deviceCard.modelData && deviceCard.modelData.name ? deviceCard.modelData.name : "Unknown Device"
                                font.pointSize: 9
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 4
                                Layout.fillWidth: true

                                StyledText {
                                    text: deviceCard.modelData ? deviceCard.modelData.address : ""
                                    color: ShellSettings.colors.active.windowText.darker(1.5)
                                    font.pointSize: 9
                                    elide: Text.ElideRight
                                }

                                StyledRectangle {
                                    radius: 3
                                    Layout.preferredWidth: statusText.implicitWidth + 6
                                    Layout.preferredHeight: statusText.implicitHeight + 2

                                    StyledText {
                                        id: statusText
                                        text: {
                                            if (!deviceCard.modelData)
                                                return "Unknown";
                                            if (deviceCard.modelData.connected)
                                                return "Connected";
                                            if (deviceCard.modelData.pairing)
                                                return "Pairing...";
                                            if (deviceCard.modelData.paired)
                                                return "Paired";
                                            return "Available";
                                        }
                                        font.pointSize: 9
                                        anchors.centerIn: parent
                                    }
                                }

                                StyledRectangle {
                                    visible: deviceCard.modelData && deviceCard.modelData.batteryAvailable
                                    radius: 3
                                    Layout.preferredWidth: batteryText.implicitWidth + 6
                                    Layout.preferredHeight: batteryText.implicitHeight + 2

                                    StyledText {
                                        id: batteryText
                                        text: deviceCard.modelData && deviceCard.modelData.batteryAvailable ? `${Math.round(deviceCard.modelData.battery * 100)}%` : ""
                                        font.pointSize: 9
                                        anchors.centerIn: parent
                                    }
                                }
                            }
                        }

                        StyledMouseArea {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            onClicked: {
                                if (deviceCard.modelData) {
                                    if (deviceCard.modelData.connected) {
                                        deviceCard.modelData.disconnect();
                                    } else {
                                        deviceCard.modelData.connect();
                                    }
                                }
                            }

                            IconImage {
                                source: {
                                    if (deviceCard.modelData && deviceCard.modelData.connected) {
                                        return Quickshell.iconPath("network-disconnect-symbolic");
                                    } else {
                                        return Quickshell.iconPath("network-connect-symbolic");
                                    }
                                }
                                anchors.fill: parent
                                anchors.margins: 2
                            }
                        }

                        // Expand Arrow
                        ExpandArrow {
                            expanded: deviceCard.expanded

                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }
                    }

                    // Dropdown Content - below main row with fade
                    ColumnLayout {
                        id: dropdownContent
                        spacing: 6
                        opacity: deviceCard.expanded ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }

                        anchors {
                            top: mainRow.bottom
                            left: parent.left
                            right: parent.right
                            margins: 8
                            topMargin: 4
                        }

                        Rectangle {
                            color: ShellSettings.colors.active.mid
                            Layout.fillWidth: true
                            height: 1
                        }

                        // Paired Toggle
                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            StyledText {
                                text: "Paired"
                                font.pointSize: 9
                                Layout.fillWidth: true
                            }

                            ToggleSwitch {
                                checked: deviceCard.modelData?.paired ?? false
                                enabled: deviceCard.modelData !== null && !deviceCard.modelData.paired

                                onCheckedChanged: {
                                    if (deviceCard.modelData && checked && !deviceCard.modelData.paired) {
                                        deviceCard.modelData.pair();
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            StyledText {
                                text: "Trusted"
                                font.pointSize: 9
                                Layout.fillWidth: true
                            }

                            ToggleSwitch {
                                checked: deviceCard.modelData?.trusted ?? false
                                enabled: deviceCard.modelData !== null && deviceCard.modelData.paired

                                onCheckedChanged: {
                                    if (deviceCard.modelData && deviceCard.modelData.trusted !== checked) {
                                        deviceCard.modelData.trusted = checked;
                                    }
                                }
                            }
                        }

                        StyledButton {
                            enabled: deviceCard.modelData !== null && deviceCard.modelData.paired

                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            onClicked: {
                                if (deviceCard.modelData) {
                                    deviceCard.modelData.forget();
                                    deviceCard.expanded = false;
                                }
                            }

                            RowLayout {
                                spacing: 4
                                anchors.centerIn: parent

                                IconImage {
                                    source: Quickshell.iconPath("edit-delete")
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                }

                                StyledText {
                                    text: "Forget Device"
                                    font.pointSize: 9
                                }
                            }
                        }
                    }
                }
            }

            Item {
                visible: !Bluetooth.devices || !Bluetooth.devices.values || Bluetooth.devices.values.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    IconImage {
                        source: Quickshell.iconPath("bluetooth-online")
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.5
                    }

                    StyledText {
                        text: Bluetooth.defaultAdapter?.enabled ? "No devices found\nEnable scanning to discover devices" : "Bluetooth is disabled\nEnable it to see devices"
                        horizontalAlignment: Text.AlignHCenter
                        color: ShellSettings.colors.active.windowText.darker(1.5)
                        font.pointSize: 9
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
