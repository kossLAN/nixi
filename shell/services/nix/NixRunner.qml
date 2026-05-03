pragma ComponentBehavior: Bound
pragma Singleton

import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import qs
import qs.widgets
import qs.notifications

Singleton {
    id: root

    function runNixPackage(packageName: string): void {
        Notifications.createNotification(notification, {
            packageName: packageName
        });
    }

    property Component notification: NotificationBacker {
        id: notification

        required property string packageName

        property bool isExpanded: false
        property string stdout: ""

        showOnFullscreen: true

        summary: `Running ${packageName}`
        iconSource: Quickshell.iconPath("nix-snowflake")

        onDiscarded: nixRunProcess.running = false

        icon: Item {
            id: iconContainer
            width: 36
            height: 36

            anchors {
                left: parent.left
                top: parent.top
            }

            IconImage {
                anchors.centerIn: parent
                source: Quickshell.iconPath("nix-snowflake")
                implicitSize: 28

                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1.0
                        to: 0.3
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        from: 0.3
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        body: ColumnLayout {
            Text {
                color: ShellSettings.colors.active.text.darker(1.25)
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                maximumLineCount: 1

                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight + 4

                text: {
                    let lines = notification.stdout.trim().split("\n");
                    let lastLine = lines[lines.length - 1].trim();
                    return lastLine !== "" ? lastLine : "Running...";
                }
            }

            StyledRectangle {
                id: stdoutContainer
                radius: 8
                clip: true
                visible: false

                property bool targetVisible: notification.stdout != "" && (notification.hidden || notification.isExpanded)

                color: {
                    if (notification.hidden) {
                        return ShellSettings.colors.active.dark;
                    }

                    return ShellSettings.colors.active.base;
                }

                Layout.fillWidth: true

                onTargetVisibleChanged: {
                    if (targetVisible) {
                        visible = true;
                        stdoutOpenAnim.restart();
                    } else {
                        stdoutCloseAnim.restart();
                    }
                }

                NumberAnimation {
                    id: stdoutOpenAnim
                    target: stdoutContainer
                    property: "implicitHeight"
                    from: 0
                    to: 150
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: stdoutCloseAnim
                    target: stdoutContainer
                    property: "implicitHeight"
                    from: 150
                    to: 0
                    duration: 200
                    easing.type: Easing.OutCubic
                    onFinished: stdoutContainer.visible = false
                }

                Flickable {
                    id: stdoutFlickable
                    contentHeight: stdoutText.implicitHeight
                    clip: true

                    anchors {
                        fill: parent
                        margins: 4
                    }

                    Text {
                        id: stdoutText
                        text: notification.stdout
                        width: stdoutFlickable.width
                        color: ShellSettings.colors.active.windowText
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: 11
                        font.family: "monospace"
                    }
                }
            }
        }

        buttons: RowLayout {
            spacing: 8

            StyledMouseArea {
                color: ShellSettings.colors.active.light
                radius: height / 2
                implicitWidth: 16
                implicitHeight: 16

                onClicked: notification.isExpanded = !notification.isExpanded

                ExpandArrow {
                    expanded: notification.isExpanded
                    anchors.fill: parent
                }
            }

            IconButton {
                color: ShellSettings.colors.active.light
                source: Quickshell.iconPath("window-minimize")
                implicitSize: 16

                onClicked: notification.hide()
            }
        }

        Process {
            id: nixRunProcess

            environment: ({
                    NIXPKGS_ALLOW_UNFREE: "1"
                })
            command: ["nix", "run", "nixpkgs#" + notification.packageName, "--impure"]
            running: true

            stdout: SplitParser {
                splitMarker: ""
                onRead: data => notification.stdout += data
            }

            stderr: SplitParser {
                splitMarker: ""
                onRead: data => notification.stdout += data
            }

            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    notification.discard();
                    notification.stdout = "";
                } else {
                    notification.summary = "Failed";
                    notification.stdout = "Exit code: " + exitCode;
                }
            }
        }
    }
}
