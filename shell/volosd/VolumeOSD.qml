pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.widgets

Scope {
    id: root

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        enabled: target !== null

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    property bool shouldShowOsd: false

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    LazyLoader {
        active: root.shouldShowOsd

        PanelWindow {
            implicitWidth: 250
            implicitHeight: 50
            color: "transparent"
            exclusiveZone: 0
            visible: true
            mask: Region {}
            anchors.bottom: true
            margins.bottom: screen.height / 10

            WlrLayershell.namespace: "shell:volosd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            StyledRectangle {
                anchors.fill: parent
                radius: height / 2

                RowLayout {
                    spacing: 10

                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 15
                    }

                    Item {
                        implicitWidth: 30
                        implicitHeight: 30

                        IconImage {
                            source: if (Pipewire.defaultAudioSink?.audio.muted) {
                                return "image://icon/audio-volume-muted";
                            } else if (Pipewire.defaultAudioSink?.audio.volume > 0.66) {
                                return "image://icon/audio-volume-high";
                            } else if (Pipewire.defaultAudioSink?.audio.volume > 0.33) {
                                return "image://icon/audio-volume-medium";
                            } else {
                                return "image://icon/audio-volume-low";
                            }

                            anchors {
                                fill: parent
                                margins: 1
                            }
                        }
                    }

                    StyledRectangle {
                        id: sliderBackground
                        implicitHeight: 10
                        radius: height / 2
                        color: ShellSettings.colors.active.alternateBase

                        Layout.fillWidth: true

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: sliderBackground.width
                                height: sliderBackground.height
                                radius: sliderBackground.radius
                                color: "black"
                            }
                        }

                        Rectangle {
                            color: ShellSettings.colors.active.highlight
                            implicitWidth: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)

                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                        }
                    }
                }
            }
        }
    }
}
