pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets
import qs.services.gsr

import qs.bar.tray

TrayBacker {
    id: root

    trayId: "gsr"
    icon: Quickshell.iconPath("media-record")

    button: StyledMouseArea {
        onClicked: root.clicked()

        GsrIcon {
            running: GpuScreenRecord.isRunning

            anchors {
                fill: parent
                margins: 5
            }
        }
    }

    menu: Item {
        id: menu
        implicitWidth: 280
        implicitHeight: container.implicitHeight + (2 * container.anchors.margins)

        property real entryHeight: 32

        ColumnLayout {
            id: container
            spacing: 4

            anchors {
                fill: parent
                margins: 8
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                // Layout.margins: 4

                GsrIcon {
                    running: GpuScreenRecord.isRunning

                    Layout.preferredHeight: 16
                    Layout.preferredWidth: 16
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    StyledText {
                        color: ShellSettings.colors.active.windowText
                        text: GpuScreenRecord.isRunning ? (GpuScreenRecord.isReplayMode ? "Replay Active" : "Recording") : "Screen Recorder"
                    }

                    StyledText {
                        color: ShellSettings.colors.active.windowText.darker(1.5)
                        text: GpuScreenRecord.isRunning ? `${GpuScreenRecord.config.codec.toUpperCase()} ${GpuScreenRecord.config.fps}fps` : "Click to start"
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                ToggleSwitch {
                    checked: GpuScreenRecord.config.enabled
                    onCheckedChanged: {
                        GpuScreenRecord.config.enabled = checked;
                    }
                }
            }

            // Save replay button
            StyledMouseArea {
                id: saveReplayButton
                visible: GpuScreenRecord.isRunning && GpuScreenRecord.isReplayMode
                color: containsMouse ? ShellSettings.colors.active.highlight : ShellSettings.colors.active.button
                radius: 8

                Layout.fillWidth: true
                Layout.preferredHeight: menu.entryHeight

                onClicked: GpuScreenRecord.saveReplay()

                RowLayout {
                    spacing: 8

                    anchors {
                        fill: parent
                        margins: 4
                        rightMargin: 8
                    }

                    IconImage {
                        source: Quickshell.iconPath("document-save")
                        implicitWidth: 24
                        implicitHeight: 24
                    }

                    StyledText {
                        color: ShellSettings.colors.active.windowText
                        text: "Save Replay"
                        Layout.fillWidth: true
                    }

                    StyledText {
                        color: ShellSettings.colors.active.windowText.darker(1.25)
                        text: `${GpuScreenRecord.config.replayBufferSize}s`
                    }
                }
            }

            // Mode toggle
            StyledMouseArea {
                id: modeToggle
                color: containsMouse ? ShellSettings.colors.active.light : "transparent"
                radius: 8

                Layout.fillWidth: true
                Layout.preferredHeight: menu.entryHeight

                RowLayout {
                    spacing: 8

                    anchors {
                        fill: parent
                        margins: 4
                        rightMargin: 8
                    }

                    IconImage {
                        source: Quickshell.iconPath(GpuScreenRecord.isReplayMode ? "media-playlist-repeat" : "camera-ready")
                        implicitWidth: 24
                        implicitHeight: 24
                    }

                    StyledText {
                        color: ShellSettings.colors.active.windowText
                        text: "Mode"
                        Layout.fillWidth: true
                    }

                    StyledText {
                        color: ShellSettings.colors.active.windowText.darker(1.25)
                        text: GpuScreenRecord.isReplayMode ? "Replay" : "Record"
                    }
                }

                onClicked: {
                    if (GpuScreenRecord.config.replayBufferSize > 0) {
                        GpuScreenRecord.config.replayBufferSize = 0;
                    } else {
                        GpuScreenRecord.config.replayBufferSize = 30;
                    }
                }
            }
        }
    }
}
