pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import qs
import qs.widgets

SettingsBacker {
    icon: "settings"

    summary: "General Settings"
    label: "General"

    content: Item {
        id: menu

        property real cardHeight: 44

        property string hostname: ""

        Process {
            id: hostnameProc
            command: ["hostname"]
            running: true
            stdout: SplitParser {
                onRead: data => menu.hostname = data.trim()
            }
        }

        ColumnLayout {
            spacing: 8
            anchors.fill: parent

            SettingsSection {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 8

                RowLayout {
                    spacing: 16

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48

                        Item {
                            id: profileImage
                            anchors.fill: parent

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: profileImage.width
                                    height: profileImage.height
                                    radius: width / 2
                                    color: "black"
                                }
                            }

                            Image {
                                source: "root:resources/general/pfp.jpg"
                                anchors.fill: parent
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            text: Quickshell.env("USER") || "User"
                            font.pointSize: 14
                            font.bold: true
                        }

                        StyledText {
                            text: menu.hostname
                            font.pointSize: 10
                            opacity: 0.6
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }

            ColumnLayout {
                spacing: 8
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8

                SettingsSection {
                    title: "Shell"

                    SettingsCard {
                        title: "Bar"
                        summary: "Show the status bar"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.barEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.barEnabled !== checked) {
                                    ShellSettings.settings.barEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Launcher"
                        summary: "Disable the launcher/search button on the bar"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.searchEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.searchEnabled !== checked) {
                                    ShellSettings.settings.searchEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                SettingsSection {
                    title: "Features"

                    SettingsCard {
                        title: "Bluetooth"
                        summary: "Show bluetooth controls on the bar & in settings"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.bluetoothEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.bluetoothEnabled !== checked) {
                                    ShellSettings.settings.bluetoothEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Screen Recording"
                        summary: "Show GPU Screen Recorder controls on the bar & in settings"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.gsrEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.gsrEnabled !== checked) {
                                    ShellSettings.settings.gsrEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "LLM Chat"
                        summary: "Show the LLM Chat in the launcher & settings"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.chatEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.chatEnabled !== checked) {
                                    ShellSettings.settings.chatEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                SettingsSection {
                    title: "Developer"

                    SettingsCard {
                        title: "Debug"
                        summary: "Disable the debug widgets in the shell"

                        controls: ToggleSwitch {
                            checked: ShellSettings.settings.debugEnabled

                            onCheckedChanged: {
                                if (ShellSettings.settings.debugEnabled !== checked) {
                                    ShellSettings.settings.debugEnabled = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
