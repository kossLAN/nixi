import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs
import qs.notifications
import qs.widgets

import qs.bar.mpris
import qs.bar.tray
import qs.bar.notifications
import qs.bar.debug

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: root

        color: ShellSettings.colors.active.window
        implicitHeight: BarManager.barEnabled ? ShellSettings.sizing.barHeight : 0
        screen: modelData

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "shell:bar"

        required property var modelData

        anchors {
            top: true
            left: true
            right: true
        }

        readonly property Popup popup: Popup {
            bar: root
            onPopupOpened: Notifications.blockToasts = true
            onPopupClosed: Notifications.blockToasts = false
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                color: "transparent"

                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    spacing: 0

                    anchors {
                        fill: parent
                        leftMargin: 5
                        rightMargin: 5
                    }

                    Item {
                        id: leftSide
                        clip: true

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Workspaces {
                            screen: root.screen
                            anchors.fill: parent
                        }
                    }

                    MprisMenu {
                        bar: root
                        Layout.maximumWidth: (root.width / 3)
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                    }

                    Item {
                        clip: true

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignRight

                        RowLayout {
                            spacing: 5
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height

                            NotificationSpawner {
                                Layout.preferredWidth: this.height
                                Layout.fillHeight: true
                            }

                            Tray {
                                bar: root
                                Layout.fillHeight: true
                            }

                            SearchButton {
                                Layout.preferredWidth: this.height
                                Layout.fillHeight: true
                            }

                            NotificationsCenter {
                                bar: root
                                Layout.preferredWidth: this.height
                                Layout.fillHeight: true
                            }

                            TimeDisplay {
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }

            Separator {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }
        }
    }
}
