pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris

import qs.widgets

Loader {
    id: root

    required property MprisPlayer player
    property int currentIndex: 0
    property int totalCount: 1
    property var colors: []

    function luminance(c: color): real {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    readonly property real bgLuminance: {
        if (!colors || colors.length < 4)
            return 0;

        const c0 = colors[0], c1 = colors[1], c2 = colors[2], c3 = colors[3];
        if (!c0 || !c1 || !c2 || !c3)
            return 0;

        return luminance(Qt.rgba(
            (c0.r + c1.r + c2.r + c3.r) / 4,
            (c0.g + c1.g + c2.g + c3.g) / 4,
            (c0.b + c1.b + c2.b + c3.b) / 4, 1
        ));
    }

    readonly property bool isLightBackground: bgLuminance > 0.5

    readonly property color textColor: isLightBackground
        ? Qt.rgba(0, 0, 0, 0.87)
        : Qt.rgba(1, 1, 1, 0.93)

    readonly property color accentColor: {
        if (!colors || colors.length < 5 || !colors[4])
            return Qt.color("purple");

        let accent = colors[4];
        let lum = luminance(accent);

        if (isLightBackground)
            return Qt.darker(accent, lum > 0.5 ? 2.0 : 1.4);

        if (lum < 0.25)
            return Qt.lighter(accent, 2.2);

        return Qt.lighter(accent, lum > 0.7 ? 1.0 : 1.5);
    }

    readonly property color railColor: isLightBackground
        ? Qt.rgba(0, 0, 0, 0.55)
        : Qt.rgba(1, 1, 1, 0.35)

    active: player !== null

    sourceComponent: RowLayout {
        id: component
        width: root.width
        height: root.height
        spacing: 20
        anchors.margins: 8

        Item {
            Layout.preferredWidth: height
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.topMargin: 16
            Layout.bottomMargin: 16

            RectangularShadow {
                anchors.fill: albumArt
                radius: 8
                blur: 16
                spread: 2
                offset: Qt.vector2d(0, 4)
                color: Qt.rgba(0, 0, 0, 0.5)
            }

            Image {
                id: albumArt
                source: Qt.resolvedUrl(root.player?.trackArtUrl ?? "")
                fillMode: Image.PreserveAspectCrop

                sourceSize {
                    width: 256
                    height: 256
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: albumArt.width
                        height: albumArt.height
                        radius: 8
                        color: "black"
                    }
                }

                anchors.fill: parent
            }
        }

        // Track info and controls container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.rightMargin: 12

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                FontMetrics {
                    id: titleMetrics
                    font.pointSize: 11
                    font.bold: true
                }

                FontMetrics {
                    id: artistMetrics
                    font.pointSize: 9
                }

                Item { Layout.fillHeight: true }

                StyledText {
                    text: root.player?.trackTitle || "Unknown Title"
                    font.bold: true
                    font.pointSize: 11
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    textColor: root.textColor

                    Layout.fillWidth: true
                    Layout.preferredHeight: titleMetrics.height
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    textColor: root.textColor
                    opacity: 0.7
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: 9

                    Layout.fillWidth: true
                    Layout.preferredHeight: artistMetrics.height
                    Layout.alignment: Qt.AlignHCenter

                    text: {
                        const artist = root.player?.trackArtist || "Unknown Artist";
                        const album = root.player?.trackAlbum || "";
                        return album ? artist + " - " + album : artist;
                    }
                }

                TextMetrics {
                    id: timeMetrics
                    text: "00:00"
                    font.pointSize: 8
                }

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    StyledText {
                        text: component.formatTime(root.player?.position ?? 0)
                        font.pointSize: 8
                        opacity: 0.7
                        textColor: root.textColor
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: timeMetrics.advanceWidth
                    }

                    StyledSlider {
                        id: progressSlider
                        enabled: root.player?.canSeek ?? false
                        value: root.player?.position ?? 0
                        from: 0
                        to: root.player?.length ?? 1

                        accentColor: root.accentColor
                        railColor: root.railColor

                        Layout.fillWidth: true

                        onMoved: {
                            if (root.player?.canSeek) {
                                root.player.position = value;
                            }
                        }
                    }

                    StyledText {
                        text: component.formatTime(root.player?.length ?? 0)
                        font.pointSize: 8
                        opacity: 0.7
                        textColor: root.textColor
                        horizontalAlignment: Text.AlignLeft
                        Layout.minimumWidth: timeMetrics.advanceWidth
                    }
                }

                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter

                    IconButton {
                        hoverColor: root.accentColor
                        iconColor: root.textColor
                        source: Quickshell.iconPath("media-playlist-shuffle")
                        implicitSize: 18
                        padding: 1
                        opacity: (root.player?.shuffleSupported ?? false)
                            ? (root.player?.shuffle ? 1.0 : 0.4)
                            : 0
                        enabled: root.player?.shuffleSupported ?? false
                        onClicked: {
                            if (root.player?.canControl && root.player?.shuffleSupported) {
                                root.player.shuffle = !root.player.shuffle;
                            }
                        }
                    }

                    IconButton {
                        hoverColor: root.accentColor
                        iconColor: root.textColor
                        source: Quickshell.iconPath("media-skip-backward")
                        implicitSize: 24
                        padding: 1
                        opacity: root.player?.canGoPrevious ? 1.0 : 0.4
                        onClicked: {
                            if (root.player?.canGoPrevious) {
                                root.player.previous();
                            }
                        }
                    }

                    IconButton {
                        hoverColor: root.accentColor
                        iconColor: root.textColor
                        source: Quickshell.iconPath(root.player?.isPlaying ? "media-playback-pause" : "media-playback-start")
                        implicitSize: 26
                        padding: 1
                        opacity: root.player?.canTogglePlaying ? 1.0 : 0.4
                        onClicked: {
                            if (root.player?.canTogglePlaying) {
                                root.player.togglePlaying();
                            }
                        }
                    }

                    IconButton {
                        hoverColor: root.accentColor
                        iconColor: root.textColor
                        source: Quickshell.iconPath("media-skip-forward")
                        implicitSize: 24
                        padding: 1
                        opacity: root.player?.canGoNext ? 1.0 : 0.4
                        onClicked: {
                            if (root.player?.canGoNext) {
                                root.player.next();
                            }
                        }
                    }

                    IconButton {
                        hoverColor: root.accentColor
                        iconColor: root.textColor
                        implicitSize: 18
                        padding: 1
                        opacity: (root.player?.loopSupported ?? false)
                            ? (root.player?.loopState !== MprisLoopState.None ? 1.0 : 0.4)
                            : 0
                        enabled: root.player?.loopSupported ?? false

                        source: {
                            if (root.player?.loopState === MprisLoopState.Track) {
                                return Quickshell.iconPath("media-playlist-repeat-song");
                            }

                            return Quickshell.iconPath("media-playlist-repeat");
                        }

                        onClicked: {
                            if (root.player?.canControl && root.player?.loopSupported) {
                                if (root.player.loopState === MprisLoopState.None) {
                                    root.player.loopState = MprisLoopState.Playlist;
                                } else if (root.player.loopState === MprisLoopState.Playlist) {
                                    root.player.loopState = MprisLoopState.Track;
                                } else {
                                    root.player.loopState = MprisLoopState.None;
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 6
                visible: root.totalCount > 1

                Repeater {
                    model: root.totalCount

                    Rectangle {
                        required property int index

                        width: 6
                        height: 6
                        radius: 3
                        color: {
                            if (index === root.currentIndex)
                                return root.accentColor;
                            else
                                return root.railColor;
                        }
                    }
                }
            }
        }

        // Update position periodically when playing
        Timer {
            running: root.player?.playbackState === MprisPlaybackState.Playing
            interval: 1000
            repeat: true
            onTriggered: root.player?.positionChanged()
        }

        function formatTime(seconds: real): string {
            const mins = Math.floor(seconds / 60);
            const secs = Math.floor(seconds % 60);
            return mins + ":" + (secs < 10 ? "0" : "") + secs;
        }
    }
}
