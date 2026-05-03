pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets
import qs.services.chat

RowLayout {
    id: root
    spacing: 1

    property bool opened: false

    ColumnLayout {
        Layout.preferredWidth: root.opened ? 225 : 24
        Layout.maximumWidth: root.opened ? 225 : 24
        Layout.margins: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            Text {
                visible: root.opened
                color: ShellSettings.colors.active.text
                text: "History"
                font.pixelSize: 13
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            StyledMouseArea {
                id: sidebarButton
                radius: 4
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24

                onClicked: root.opened = !root.opened

                IconImage {
                    source: Quickshell.iconPath(root.opened ? "sidebar-collapse-left" : "sidebar-expand-left")
                    anchors.fill: parent
                    anchors.margins: 2
                }
            }
        }

        // Conversations list
        ListView {
            id: conversationsList
            visible: root.opened
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            clip: true

            model: ChatConnector.conversations

            delegate: StyledMouseArea {
                id: convDelegate
                width: conversationsList.width
                height: 40
                radius: 6

                required property var modelData
                required property int index

                property bool isActive: ChatConnector.currentConversationId === modelData.id

                color: isActive ? ShellSettings.colors.inactive.highlight : "transparent"
                hoverColor: ShellSettings.colors.active.highlight

                onClicked: ChatConnector.loadConversation(modelData.id)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            color: ShellSettings.colors.active.text
                            text: convDelegate.modelData.title
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                        }

                        StyledText {
                            color: ShellSettings.colors.active.text.darker(1.25)
                            text: Qt.formatDateTime(convDelegate.modelData.updatedAt, "MMM d, h:mm ap")
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                        }
                    }

                    StyledMouseArea {
                        radius: 4
                        hoverColor: ShellSettings.colors.extra.close

                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20

                        onClicked: ChatConnector.deleteConversation(convDelegate.modelData.id)

                        IconImage {
                            source: Quickshell.iconPath("edit-delete")

                            anchors {
                                fill: parent
                                margins: 2
                            }
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: conversationsList.count === 0
                color: ShellSettings.colors.active.text
                opacity: 0.5
                text: "No conversations yet"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
        }

        StyledMouseArea {
            visible: root.opened
            radius: 6

            Layout.fillWidth: true
            Layout.preferredHeight: 40

            onClicked: ChatConnector.newConversation()

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 6

                IconImage {
                    source: Quickshell.iconPath("list-add")
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }

                Text {
                    Layout.fillWidth: true
                    color: ShellSettings.colors.active.text
                    text: "New chat"
                    font.pixelSize: 12
                }
            }
        }

        Item {
            visible: !root.opened
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Separator {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
    }
}
