pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import NixiUtils
import qs
import qs.widgets
import qs.services.mpris

Item {
    id: root
    required property LockState state
    required property string wallpaper
    property bool showSessionSelector: false

    property string hostname: ""

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true
        stdout: SplitParser {
            onRead: data => root.hostname = data.trim()
        }
    }

    Item {
        anchors.fill: parent

        Image {
            id: bgImage
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            anchors.fill: parent
            visible: false
        }

        FastBlur {
            anchors.fill: bgImage
            source: bgImage
            radius: 80
            transparentBorder: false
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.3
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(0, 0, 0, 0.1)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.4)
                }
            }
        }
    }

    // Date and time display
    ColumnLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 120
        }
        spacing: 10

        Text {
            id: clock
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
            font.pointSize: 72
            color: "white"
            text: {
                const now = this.date;
                let hours = now.getHours();
                const minutes = now.getMinutes().toString().padStart(2, '0');
                hours = hours % 12;
                hours = hours ? hours : 12;
                return `${hours}:${minutes}`;
            }

            property var date: new Date()
            Layout.alignment: Qt.AlignHCenter

            Timer {
                running: true
                repeat: true
                interval: 1000
                onTriggered: clock.date = new Date()
            }

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 20
                samples: 41
                color: Qt.rgba(1, 1, 1, 0.3)
            }
        }
    }

    // Session selector (top right)
    StyledDropdown {
        id: sessionSelector
        visible: root.showSessionSelector && model.length > 1
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 20
            rightMargin: 20
        }
        width: 160
        height: 32
        currentValue: root.state.session
        model: {
            const sessions = [
                { value: "jay run", label: "Jay", binary: "jay" },
                { value: "niri-session", label: "Niri", binary: "niri-session" },
                { value: "start-hyprland", label: "Hyprland", binary: "start-hyprland" }
            ];
            return sessions.filter(s => NixiUtils.inPath(s.binary));
        }
        onSelected: value => root.state.session = value
        onModelChanged: {
            if (model.length === 1)
                root.state.session = model[0].value;
        }
    }

    // Floating login card
    Item {
        id: cardContainer
        visible: Window.active
        anchors.centerIn: parent
        width: cardContent.implicitWidth + 24
        height: cardContent.implicitHeight + 24

        RectangularShadow {
            anchors.fill: card
            radius: card.radius
            blur: 16
            spread: 2
            offset: Qt.vector2d(0, 4)
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        StyledRectangle {
            id: card
            anchors.fill: parent

            ColumnLayout {
                id: cardContent
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                // User info row
                RowLayout {
                    spacing: 16
                    Layout.alignment: Qt.AlignLeft

                    ClippingRectangle {
                        id: profileImage
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64

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

                    ColumnLayout {
                        spacing: 2

                        StyledText {
                            text: "koss" 
                            font.pointSize: 14
                            font.bold: true
                        }

                        StyledText {
                            text: root.hostname
                            font.pointSize: 10
                            opacity: 0.6
                        }
                    }
                }

                // Login field with inlaid button
                Item {
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 38

                    Rectangle {
                        id: fieldBackground
                        anchors.fill: parent
                        radius: 8
                        color: ShellSettings.colors.active.alternateBase
                        border.width: 1
                        border.color: ShellSettings.colors.active.light
                        scale: passwordBox.activeFocus ? 1.02 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        transform: Translate {
                            id: shakeTransform
                            x: 0
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 0
                            spacing: 0

                            TextInput {
                                id: passwordBox
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                color: ShellSettings.colors.active.windowText
                                echoMode: TextInput.Password
                                inputMethodHints: Qt.ImhSensitiveData
                                font.pointSize: 11
                                focus: true
                                clip: true
                                enabled: !root.state.unlockInProgress

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Password"
                                    color: ShellSettings.colors.active.windowText
                                    opacity: 0.4
                                    font.pointSize: 11
                                    visible: passwordBox.text.length === 0 && !passwordBox.activeFocus
                                    renderType: Text.NativeRendering
                                }

                                onTextChanged: root.state.currentText = text
                                onAccepted: root.state.tryUnlock()

                                Connections {
                                    target: root.state

                                    function onCurrentTextChanged() {
                                        if (!shakeAnimation.running) {
                                            passwordBox.text = root.state.currentText;
                                        }
                                    }

                                    function onShowFailureChanged() {
                                        if (root.state.showFailure && !shakeAnimation.running) {
                                            shakeAnimation.start();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: ShellSettings.colors.active.light
                            }

                            Item {
                                Layout.preferredWidth: 38
                                Layout.fillHeight: true
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    // extend left to cover parent's right radius
                                    anchors.leftMargin: -fieldBackground.radius
                                    color: ShellSettings.colors.active.mid
                                    radius: fieldBackground.radius
                                    border.width: 1
                                    border.color: ShellSettings.colors.active.light
                                }

                                MouseArea {
                                    id: submitButton
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.state.unlockInProgress && passwordBox.text.length > 0
                                    onClicked: root.state.tryUnlock()

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: -fieldBackground.radius
                                        radius: fieldBackground.radius
                                        color: ShellSettings.colors.active.highlight
                                        visible: submitButton.containsMouse
                                    }

                                    IconButton {
                                        anchors.centerIn: parent
                                        implicitSize: 20
                                        source: Quickshell.iconPath("go-next")
                                        iconColor: ShellSettings.colors.active.buttonText
                                        hoverColor: "transparent"
                                        opacity: passwordBox.text.length > 0 ? 1.0 : 0.3

                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SequentialAnimation {
                        id: shakeAnimation

                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: -8; duration: 50
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: 8; duration: 100
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: -6; duration: 80
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: 6; duration: 80
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: -3; duration: 60
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: shakeTransform; property: "x"
                            to: 0; duration: 50
                            easing.type: Easing.OutQuad
                        }

                        onFinished: {
                            passwordBox.text = "";
                        }
                    }
                }

            }
        }
    }

    // Floating MPRIS player card
    Item {
        id: mprisContainer
        visible: Mpris.trackedPlayer !== null && Window.active
        width: cardContent.implicitWidth + 24
        height: mprisContent.implicitHeight + 24

        anchors {
            top: cardContainer.bottom
            topMargin: 12
            horizontalCenter: parent.horizontalCenter
        }

        RectangularShadow {
            anchors.fill: mprisCard
            radius: mprisCard.radius
            blur: 16
            spread: 2
            offset: Qt.vector2d(0, 4)
            color: Qt.rgba(0, 0, 0, 0.5)
        }

        StyledRectangle {
            id: mprisCard
            anchors.fill: parent

            RowLayout {
                id: mprisContent
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 12

                Item {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48

                    Image {
                        id: miniAlbumArt
                        source: Qt.resolvedUrl(Mpris.trackedPlayer?.trackArtUrl ?? "")
                        fillMode: Image.PreserveAspectCrop
                        anchors.fill: parent

                        sourceSize {
                            width: 96
                            height: 96
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: miniAlbumArt.width
                                height: miniAlbumArt.height
                                radius: 6
                                color: "black"
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: Mpris.trackedPlayer?.trackTitle || "Unknown"
                        font.pointSize: 9
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: 160
                    }

                    StyledText {
                        text: Mpris.trackedPlayer?.trackArtist || "Unknown"
                        font.pointSize: 8
                        opacity: 0.6
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: 160
                    }
                }

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    IconButton {
                        iconColor: ShellSettings.colors.active.windowText
                        hoverColor: ShellSettings.colors.active.accent
                        source: Quickshell.iconPath("media-skip-backward")
                        implicitSize: 18
                        opacity: Mpris.trackedPlayer?.canGoPrevious ? 1.0 : 0.4
                        onClicked: {
                            if (Mpris.trackedPlayer?.canGoPrevious)
                                Mpris.trackedPlayer.previous();
                        }
                    }

                    IconButton {
                        iconColor: ShellSettings.colors.active.windowText
                        hoverColor: ShellSettings.colors.active.accent
                        source: Quickshell.iconPath(Mpris.trackedPlayer?.isPlaying ? "media-playback-pause" : "media-playback-start")
                        implicitSize: 22
                        opacity: Mpris.trackedPlayer?.canTogglePlaying ? 1.0 : 0.4
                        onClicked: {
                            if (Mpris.trackedPlayer?.canTogglePlaying)
                                Mpris.trackedPlayer.togglePlaying();
                        }
                    }

                    IconButton {
                        iconColor: ShellSettings.colors.active.windowText
                        hoverColor: ShellSettings.colors.active.accent
                        source: Quickshell.iconPath("media-skip-forward")
                        implicitSize: 18
                        opacity: Mpris.trackedPlayer?.canGoNext ? 1.0 : 0.4
                        onClicked: {
                            if (Mpris.trackedPlayer?.canGoNext)
                                Mpris.trackedPlayer.next();
                        }
                    }
                }
            }
        }
    }

    // testing button
    Button {
        visible: ShellSettings.settings.debugEnabled
        text: "Emergency Unlock"
        onClicked: root.state.unlocked()

        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 20
        }
    }
}
