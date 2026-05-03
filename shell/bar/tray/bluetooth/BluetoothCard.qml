import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

import qs
import qs.widgets

Item {
    id: root

    property BluetoothDevice device: null
    property BluetoothAdapter adapter: null

    property bool isAdapterMode: adapter !== null

    RowLayout {
        spacing: 2
        anchors.fill: parent

        Item {
            width: 24
            height: 24
            clip: true

            Layout.alignment: Qt.AlignVCenter
            Layout.margins: root.isAdapterMode ? 4 : 6

            IconImage {
                source: {
                    if (root.isAdapterMode) {
                        if (root.adapter && root.adapter.enabled) {
                            return Quickshell.iconPath("bluetooth-online");
                        } else {
                            return Quickshell.iconPath("bluetooth-offline");
                        }
                    } else {
                        return root.device && root.device.icon ? Quickshell.iconPath(root.device.icon) : "";
                    }
                }
                implicitWidth: 24
                implicitHeight: 24
                width: 24
                height: 24
                anchors.centerIn: parent
                mipmap: true
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                color: ShellSettings.colors.active.windowText
                elide: Text.ElideRight

                text: {
                    if (root.isAdapterMode) {
                        return root.adapter ? `Bluetooth (${root.adapter.adapterId})` : "Bluetooth (No Adapter)";
                    } else {
                        return root.device && root.device.name ? root.device.name : "Unknown Device";
                    }
                }

                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
            }

            StyledText {
                color: ShellSettings.colors.active.windowText.darker(1.5)
                elide: Text.ElideRight

                text: {
                    if (root.isAdapterMode) {
                        return root.adapter ? (root.adapter.enabled ? "Enabled" : "Disabled") : "Not Available";
                    } else {
                        return root.device ? (root.device.connected ? "Connected" : "Disconnected") : "Unknown";
                    }
                }

                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
            }
        }

        RowLayout {
            spacing: 2

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 4

            StyledMouseArea {
                visible: root.isAdapterMode
                enabled: root.adapter !== null

                Layout.preferredWidth: this.height
                Layout.fillHeight: true

                onClicked: {
                    if (root.adapter) {
                        root.adapter.discovering = !root.adapter.discovering;
                    }
                }

                Timer {
                    id: discoveryTimer
                    interval: 15000
                    running: root.adapter?.discovering ?? false

                    onTriggered: {
                        if (root.adapter) {
                            root.adapter.discovering = false;
                        }
                    }
                }

                IconImage {
                    id: searchIcon
                    transformOrigin: Item.Center

                    source: {
                        if (root.adapter && root.adapter.discovering) {
                            return Quickshell.iconPath("reload");
                        } else {
                            return Quickshell.iconPath("cm_search");
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
                        running: root.adapter && root.adapter.discovering
                        onRunningChanged: {
                            if (!running)
                                searchIcon.rotation = 0;
                        }
                    }
                }
            }

            ToggleSwitch {
                visible: root.isAdapterMode
                enabled: root.adapter !== null
                checked: root.adapter?.enabled ?? false

                Layout.alignment: Qt.AlignVCenter

                onCheckedChanged: {
                    if (root.adapter && root.adapter.enabled !== checked) {
                        root.adapter.enabled = checked;
                    }
                }
            }

            StyledMouseArea {
                visible: !root.isAdapterMode
                Layout.preferredWidth: this.height
                Layout.fillHeight: true
                enabled: root.device !== null

                onClicked: {
                    if (root.device) {
                        if (root.device.connected) {
                            root.device.disconnect();
                        } else {
                            root.device.connect();
                        }
                    }
                }

                IconImage {
                    source: {
                        if (root.device && root.device.connected) {
                            return Quickshell.iconPath("network-disconnect-symbolic");
                        } else {
                            return Quickshell.iconPath("network-connect-symbolic");
                        }
                    }

                    anchors {
                        fill: parent
                        margins: 2
                    }
                }
            }
        }
    }
}
