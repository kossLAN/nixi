pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import qs
import qs.bar
import qs.widgets
import qs.services.mpris
import NixiUtils

StyledMouseArea {
    id: root

    required property var bar
    property bool showMenu: false

    property string activeTitle: Mpris.trackedPlayer?.trackTitle ?? ""
    property string displayedTitle: activeTitle
    property bool isPlaying: Mpris.trackedPlayer?.isPlaying ?? false
    property bool displayedIsPlaying: isPlaying

    visible: Mpris.trackedPlayer !== null
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    implicitWidth: contentRow.implicitWidth + 8
    implicitHeight: contentRow.implicitHeight

    onActiveTitleChanged: fadeOut.start()
    onIsPlayingChanged: fadeOut.start()

    onClicked: event => {
        if (event.button == Qt.LeftButton) {
            showMenu = !showMenu;
        } else if (event.button == Qt.RightButton) {
            if (!Mpris.trackedPlayer)
                return;

            if (Mpris.trackedPlayer.isPlaying)
                Mpris.trackedPlayer.pause();
            else
                Mpris.trackedPlayer.play();
        }
    }

    NumberAnimation {
        id: fadeOut
        target: contentRow
        property: "opacity"
        to: 0
        duration: 100

        onFinished: {
            root.displayedTitle = root.activeTitle;
            root.displayedIsPlaying = root.isPlaying;
            fadeIn.start();
        }
    }

    NumberAnimation {
        id: fadeIn
        target: contentRow
        property: "opacity"
        to: 1
        duration: 100
    }

    RowLayout {
        id: contentRow
        spacing: 5

        anchors {
            fill: parent
            leftMargin: 4
            rightMargin: 4
        }

        Item {
            Layout.preferredWidth: root.height
            Layout.preferredHeight: root.height

            IconImage {
                id: playIcon
                source: Quickshell.iconPath(root.displayedIsPlaying ? "media-pause" : "media-play")

                anchors {
                    fill: parent
                    margins: 1
                }
            }
        }

        StyledText {
            id: windowText
            text: root.displayedTitle
            color: ShellSettings.colors.active.windowText
            font.pointSize: ShellSettings.sizing.barHeight / 2.5
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }

    property PopupItem menu: PopupItem {
        id: menu
        owner: root
        popup: root.bar.popup
        show: root.showMenu
        centered: true
        onClosed: root.showMenu = false

        implicitWidth: 525
        implicitHeight: 150

        CachedImage {
            id: artCache

            source: {
                const idx = players.currentIndex;

                if (idx >= 0 && idx < Mpris.sortedPlayers.length) {
                    return Mpris.sortedPlayers[idx]?.trackArtUrl ?? "";
                }

                return "";
            }
        }

        ColorQuantizer {
            id: colorQuantizer
            source: artCache.ready ? artCache.cachedSource : ""
            depth: 3
            rescaleSize: 64
        }

        function luminance(c: color): real {
            return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        }

        property color adjustedWaveColor: {
            let colors = colorQuantizer.colors;
            if (!colors || colors.length < 6)
                return Qt.rgba(0.4, 0.3, 0.5, 1);

            let wave = colors[5];
            let bgLum = (luminance(colors[0]) + luminance(colors[1]) + luminance(colors[2]) + luminance(colors[3])) / 4;
            let waveLum = luminance(wave);

            if (Math.abs(waveLum - bgLum) < 0.2) {
                if (bgLum > 0.5)
                    return Qt.darker(wave, 2.0);
                else
                    return Qt.lighter(wave, 2.0);
            }

            return wave;
        }

        // Cava-based audio visualization
        property var cavaData: []
        property real cavaPeak: {
            if (cavaData.length === 0)
                return 0;
            let max = 0;
            for (let i = 0; i < cavaData.length; i++) {
                if (cavaData[i] > max)
                    max = cavaData[i];
            }
            return max;
        }

        Process {
            id: cavaProc

            property string cavaConf: {
                let qtUrl = Qt.resolvedUrl("root:bar/mpris/cava.conf").toString();
                return qtUrl.split("file://")[1];
            }

            running: root.showMenu && root.isPlaying
            command: ["cava", "-p", cavaConf]

            stdout: SplitParser {
                onRead: data => {
                    let newPoints = data.split(";").map(p => parseFloat(p.trim()) / 1000).filter(p => !isNaN(p));
                    let smoothFactor = 0.3;

                    if (menu.cavaData.length === 0 || menu.cavaData.length !== newPoints.length) {
                        menu.cavaData = newPoints;
                    } else {
                        let smoothed = [];

                        for (let i = 0; i < newPoints.length; i++) {
                            let oldVal = menu.cavaData[i];
                            let newVal = newPoints[i];

                            smoothed.push(oldVal + (newVal - oldVal) * smoothFactor);
                        }

                        menu.cavaData = smoothed;
                    }
                }
            }
        }

        backgroundComponent: ClippingRectangle {
            clip: true
            color: "transparent"
            radius: 12
            contentUnderBorder: true

            ShaderEffect {
                fragmentShader: "root:resources/shaders/audioplasma.frag.qsb"
                vertexShader: "root:resources/shaders/audioplasma.vert.qsb"
                anchors.fill: parent

                property color color0: colorQuantizer.colors[0] ?? Qt.rgba(0.1, 0.1, 0.2, 1)
                property color color1: colorQuantizer.colors[1] ?? Qt.rgba(0.2, 0.1, 0.3, 1)
                property color color2: colorQuantizer.colors[2] ?? Qt.rgba(0.1, 0.2, 0.3, 1)
                property color color3: colorQuantizer.colors[3] ?? Qt.rgba(0.15, 0.15, 0.25, 1)
                property color waveColor: menu.adjustedWaveColor
                property real animTime: 0
                property vector4d params: Qt.vector4d(animTime, 0, 0, 0)

                function getBar(i) {
                    return 1.5 * menu.cavaData[i] ?? 0.0;
                }

                property vector4d bars0: Qt.vector4d(getBar(0), getBar(1), getBar(2), getBar(3))
                property vector4d bars1: Qt.vector4d(getBar(4), getBar(5), getBar(6), getBar(7))
                property vector4d bars2: Qt.vector4d(getBar(8), getBar(9), getBar(10), getBar(11))
                property vector4d bars3: Qt.vector4d(getBar(12), getBar(13), getBar(14), getBar(15))
                property vector4d bars4: Qt.vector4d(getBar(16), getBar(17), getBar(18), getBar(19))

                NumberAnimation on animTime {
                    from: 0
                    to: 1
                    duration: 10000
                    loops: Animation.Infinite
                    running: root.showMenu && root.isPlaying
                }

                Behavior on color0 {
                    ColorAnimation {
                        duration: 300
                    }
                }
                Behavior on color1 {
                    ColorAnimation {
                        duration: 300
                    }
                }
                Behavior on color2 {
                    ColorAnimation {
                        duration: 300
                    }
                }
                Behavior on color3 {
                    ColorAnimation {
                        duration: 300
                    }
                }
                Behavior on waveColor {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }

            Rectangle {
                color: "black"
                opacity: 0.1
                anchors.fill: parent
            }
        }

        StyledListView {
            id: players
            spacing: 0
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            clip: false

            anchors.fill: parent

            model: Mpris.sortedPlayers

            delegate: MprisCard {
                required property var modelData
                required property int index

                player: modelData
                currentIndex: index
                totalCount: players.count
                width: players.width
                height: players.height
                colors: colorQuantizer.colors
            }
        }
    }
}
