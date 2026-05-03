pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs
import qs.widgets
import qs.services.gsr

SettingsBacker {
    icon: "simplescreenrecorder-panel"

    enabled: ShellSettings.settings.gsrEnabled

    summary: "Screen Recording"
    label: "Recording"

    content: Item {
        id: menu

        property real cardHeight: 44
        property real tallCardHeight: 48

        function audioDevices() {
            if (GpuScreenRecord.config.audioInput === "")
                return [];

            return GpuScreenRecord.config.audioInput.split(",").map(device => device.trim()).filter(device => device !== "");
        }

        function hasAudioDevice(device: string): bool {
            return audioDevices().indexOf(device) !== -1;
        }

        function setAudioDeviceEnabled(device: string, enabled: bool): void {
            let devices = audioDevices().filter(entry => entry !== device);

            if (enabled)
                devices.push(device);

            GpuScreenRecord.config.audioInput = devices.join(",");
        }

        Flickable {
            id: scrollView

            clip: true
            contentWidth: width
            contentHeight: settingsContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            anchors {
                fill: parent
                margins: 8
            }

            ColumnLayout {
                id: settingsContent

                spacing: 8
                width: scrollView.width

                SettingsSection {
                    title: "Capture"

                    SettingsCard {
                        title: "Show Cursor"
                        summary: "Include cursor in recording"

                        controls: ToggleSwitch {
                            checked: GpuScreenRecord.config.cursor

                            onCheckedChanged: {
                                if (GpuScreenRecord.config.cursor !== checked) {
                                    GpuScreenRecord.config.cursor = checked;
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Capture"
                        summary: "What to record"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 120
                            model: [
                                {
                                    label: "Screen",
                                    value: "screen"
                                },
                                {
                                    label: "Portal",
                                    value: "portal"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.window
                            onSelected: value => GpuScreenRecord.config.window = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "FPS"
                        summary: "Frames per second"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 80
                            model: ["30", "60", "120", "144", "165", "240"].map(x => {
                                return {
                                    label: x,
                                    value: x
                                };
                            })

                            currentValue: GpuScreenRecord.config.fps.toString()
                            onSelected: value => GpuScreenRecord.config.fps = parseInt(value)
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Resolution"
                        summary: "Output resolution limit (0x0 for original)"

                        controls: StyledTextInput {
                            text: GpuScreenRecord.config.size
                            width: 120
                            placeholderText: "e.g., 1920x1080"

                            onAccepted: GpuScreenRecord.config.size = text
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                SettingsSection {
                    title: "Encoding"

                    SettingsCard {
                        title: "Codec"
                        summary: "Video codec for encoding"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 100
                            model: [
                                {
                                    label: "H.264",
                                    value: "h264"
                                },
                                {
                                    label: "HEVC",
                                    value: "hevc"
                                },
                                {
                                    label: "AV1",
                                    value: "av1"
                                },
                                {
                                    label: "VP8",
                                    value: "vp8"
                                },
                                {
                                    label: "VP9",
                                    value: "vp9"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.codec
                            onSelected: value => GpuScreenRecord.config.codec = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Quality"
                        summary: "Encoding quality preset"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 100
                            model: [
                                {
                                    label: "Ultra",
                                    value: "ultra"
                                },
                                {
                                    label: "Very High",
                                    value: "very_high"
                                },
                                {
                                    label: "High",
                                    value: "high"
                                },
                                {
                                    label: "Medium",
                                    value: "medium"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.quality
                            onSelected: value => GpuScreenRecord.config.quality = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Container"
                        summary: "Output file format"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 80
                            model: [
                                {
                                    label: "MP4",
                                    value: "mp4"
                                },
                                {
                                    label: "MKV",
                                    value: "mkv"
                                },
                                {
                                    label: "FLV",
                                    value: "flv"
                                },
                                {
                                    label: "WebM",
                                    value: "webm"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.containerFormat
                            onSelected: value => GpuScreenRecord.config.containerFormat = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                SettingsSection {
                    title: "Replay"

                    SettingsCard {
                        title: "Buffer Size"
                        summary: "Replay buffer duration (0 = recording mode)"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 100
                            model: [
                                {
                                    label: "Disabled",
                                    value: "0"
                                },
                                {
                                    label: "15 sec",
                                    value: "15"
                                },
                                {
                                    label: "30 sec",
                                    value: "30"
                                },
                                {
                                    label: "60 sec",
                                    value: "60"
                                },
                                {
                                    label: "120 sec",
                                    value: "120"
                                },
                                {
                                    label: "300 sec",
                                    value: "300"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.replayBufferSize.toString()
                            onSelected: value => GpuScreenRecord.config.replayBufferSize = parseInt(value)
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Storage"
                        summary: "Where to keep replay buffer"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 80
                            model: [
                                {
                                    label: "RAM",
                                    value: "ram"
                                },
                                {
                                    label: "Disk",
                                    value: "disk"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.replayStorage
                            onSelected: value => GpuScreenRecord.config.replayStorage = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }

                SettingsSection {
                    title: "Audio"

                    SettingsCard {
                        title: "Output"
                        summary: "Append default_output"

                        controls: RowLayout {
                            implicitWidth: 80
                            implicitHeight: 28

                            Item {
                                Layout.fillWidth: true
                            }

                            ToggleSwitch {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                checked: menu.hasAudioDevice("default_output")

                                onCheckedChanged: {
                                    if (menu.hasAudioDevice("default_output") !== checked) {
                                        menu.setAudioDeviceEnabled("default_output", checked);
                                    }
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Input"
                        summary: "Append default_input"

                        controls: RowLayout {
                            implicitWidth: 80
                            implicitHeight: 28

                            Item {
                                Layout.fillWidth: true
                            }

                            ToggleSwitch {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                checked: menu.hasAudioDevice("default_input")

                                onCheckedChanged: {
                                    if (menu.hasAudioDevice("default_input") !== checked) {
                                        menu.setAudioDeviceEnabled("default_input", checked);
                                    }
                                }
                            }
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    SettingsCard {
                        title: "Audio Codec"
                        summary: "Audio encoding format"

                        controls: StyledDropdown {
                            color: ShellSettings.colors.active.alternateBase
                            width: 80
                            model: [
                                {
                                    label: "Opus",
                                    value: "opus"
                                },
                                {
                                    label: "AAC",
                                    value: "aac"
                                },
                                {
                                    label: "FLAC",
                                    value: "flac"
                                }
                            ]

                            currentValue: GpuScreenRecord.config.audioCodec
                            onSelected: value => GpuScreenRecord.config.audioCodec = value
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.cardHeight
                    }

                    Layout.fillWidth: true
                }
            }
        }
    }
}
