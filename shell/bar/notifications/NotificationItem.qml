pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.bar
import qs.widgets
import qs.notifications

StyledRectangle {
    id: root
    color: ShellSettings.colors.active.base

    required property NotificationBacker backer
    required property PopupItem menu

    // implicitWidth: parent.toastWidth
    implicitHeight: Math.max(50, wrapper.implicitHeight)

    WrapperItem {
        id: wrapper
        margin: 8

        implicitWidth: parent.width

        RowLayout {
            id: content
            spacing: 8

            Loader {
                active: root.backer?.icon ?? false
                sourceComponent: root.backer?.icon ?? null

                onLoaded: visible = item.visible

                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                spacing: 2

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop

                RowLayout {
                    spacing: 8

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Summary (title) text
                    Text {
                        id: summaryText
                        text: root.backer?.summary ?? ""
                        color: ShellSettings.colors.active.text
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        Layout.fillWidth: true
                        Layout.preferredHeight: summaryText.contentHeight
                    }

                    Text {
                        id: timeText
                        text: getTimeAgoText()
                        color: ShellSettings.colors.active.text.darker(1.5)
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        font {
                            pixelSize: 12
                            weight: Font.Medium
                        }

                        Connections {
                            target: root.menu

                            function onShowChanged() {
                                if (root.menu.show)
                                    timeText.text = timeText.getTimeAgoText();

                                timeAgoTimer.running = root.menu.show;
                            }
                        }

                        Timer {
                            id: timeAgoTimer
                            running: true
                            interval: 60000
                            repeat: true
                            onTriggered: timeText.text = timeText.getTimeAgoText()
                        }

                        function getTimeAgoText() {
                            const timeTracked = root.backer?.timeTracked;

                            if (timeTracked == undefined)
                                return "";

                            const currentTime = new Date();
                            const diffMs = currentTime - timeTracked;

                            const diffSeconds = Math.floor(diffMs / 1000);
                            const diffMinutes = Math.floor(diffSeconds / 60);
                            const diffHours = Math.floor(diffMinutes / 60);
                            const diffDays = Math.floor(diffHours / 24);

                            if (diffDays > 0)
                                return `${diffDays}d ago`;
                            if (diffHours > 0)
                                return `${diffHours}h ago`;
                            if (diffMinutes > 0)
                                return `${diffMinutes}m ago`;

                            return "now";
                        }

                        Layout.preferredWidth: timeText.contentWidth
                        Layout.preferredHeight: timeText.contentHeight
                    }

                    // Buttons, typically close
                    IconButton {
                        color: ShellSettings.colors.active.light
                        source: Quickshell.iconPath("window-close")
                        implicitSize: 16
                        padding: 2
                        onClicked: root.backer.discard()
                    }
                }

                Loader {
                    active: root.backer?.body ?? false
                    sourceComponent: root.backer?.body ?? null

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
