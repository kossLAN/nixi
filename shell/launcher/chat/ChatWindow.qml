pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets
import qs.launcher
import qs.services.chat

ColumnLayout {
    id: root

    property bool floating: false

    spacing: 0

    RowLayout {
        spacing: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        Layout.margins: 4
        Layout.leftMargin: 16

        Rectangle {
            width: 8
            height: 8
            radius: 4

            Layout.rightMargin: 16

            color: {
                if (ChatConnector.busy)
                    return ShellSettings.colors.active.accent;

                return (ChatConnector.currentProvider?.available ? "#4ade80" : "#ef4444");
            }

            SequentialAnimation on opacity {
                running: ChatConnector.busy
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.3
                    duration: 500
                }

                NumberAnimation {
                    to: 1.0
                    duration: 500
                }
            }
        }

        ModelDropdown {
            id: modelDropdown
            color: ShellSettings.colors.active.mid

            Layout.preferredWidth: 200
            Layout.preferredHeight: 28

            onSelected: (providerId, model) => ChatConnector.setProviderAndModel(providerId, model)
        }

        StyledButton {
            id: floatingButton
            checked: root.floating
            color: ShellSettings.colors.active.mid
            checkedColor: ShellSettings.colors.inactive.highlight
            hoverColor: root.floating ? ShellSettings.colors.extra.close : ShellSettings.colors.inactive.highlight

            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.leftMargin: 4

            onClicked: {
                if (root.floating) {
                    Launcher.closeFloatingChat();
                } else {
                    Launcher.openFloatingChat();
                }
            }

            IconImage {
                source: Quickshell.iconPath("focus-windows")
                anchors.fill: parent
                anchors.margins: 4
            }
        }

        StyledButton {
            id: searchButton
            visible: ChatConnector.supportsInternetSearch
            checked: ChatConnector.internetSearchEnabled
            color: ShellSettings.colors.active.button
            hoverColor: checked ? ShellSettings.colors.inactive.highlight : ShellSettings.colors.active.highlight

            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.leftMargin: 4

            onClicked: ChatConnector.toggleInternetSearch()

            IconImage {
                source: Quickshell.iconPath("globe")
                anchors.fill: parent
                anchors.margins: 4
            }
        }
    }

    // Messages area
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: messagesList

            property bool autoScroll: true

            spacing: 0
            clip: true
            cacheBuffer: 2000 // needs to be a pretty big buffer, otherwise scrolling will freak out
            anchors.fill: parent

            ScrollBar.vertical: ScrollBar {}

            onMovingChanged: {
                if (moving) {
                    autoScroll = false;
                } else {
                    if (atYEnd) {
                        autoScroll = true;
                    }
                }
            }

            model: ChatConnector.history

            footer: Rectangle {
                id: streamingFooter

                property bool hasResponse: ChatConnector.currentResponse !== ""

                width: messagesList.width
                height: hasResponse ? footerColumn.implicitHeight + 16 : 0
                color: "transparent"

                Column {
                    id: footerColumn
                    spacing: 6
                    width: messagesList.width - 16

                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 8
                    }

                    ChatResponse {
                        id: streamingContent
                        visible: streamingFooter.hasResponse
                        width: parent.width
                        text: ChatConnector.currentResponse
                    }
                }
            }

            delegate: Item {
                id: messageDelegate

                required property var modelData
                required property int index

                property bool isUser: modelData.role === "user"

                implicitWidth: ListView.view.width
                implicitHeight: (isUser ? userRequest.height : markdownContent.implicitHeight) + 16

                HoverHandler {
                    id: messageHover
                }

                // User message
                ChatRequest {
                    id: userRequest
                    visible: messageDelegate.isUser
                    text: messageDelegate.modelData.content
                    images: messageDelegate.modelData.images ?? []
                    implicitWidth: messagesList.width - 16

                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 8
                    }
                }

                // Assistant message
                ChatResponse {
                    id: markdownContent
                    visible: !messageDelegate.isUser
                    width: messagesList.width - 16
                    text: messageDelegate.modelData.content

                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 8
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ChatConnector.history.length === 0 && ChatConnector.currentResponse === ""
                color: ShellSettings.colors.active.text
                opacity: 0.5
                font.pixelSize: 14

                text: {
                    if (ChatConnector.currentProvider?.available)
                        return "Start a conversation...";

                    return "Connecting to service...";
                }
            }

            function scrollToBottom() {
                positionViewAtEnd();
            }

            function scrollToBottomDelayed() {
                positionViewAtEnd();
                Qt.callLater(positionViewAtEnd);
            }

            Component.onCompleted: scrollToBottomDelayed()

            Connections {
                target: ChatConnector

                function onHistoryUpdated() {
                    messagesList.scrollToBottomDelayed();
                }

                function onResponseChunk() {
                    if (messagesList.autoScroll) {
                        messagesList.scrollToBottom();
                    }
                }
            }

            Connections {
                target: root

                function onVisibleChanged() {
                    if (root.visible) {
                        messagesList.scrollToBottomDelayed();
                    }
                }
            }
        }

        StyledButton {
            visible: !messagesList.autoScroll
            color: ShellSettings.colors.active.dark
            hoverColor: color.lighter(1.25)
            width: 32
            height: 32
            onClicked: {
                messagesList.autoScroll = true;
                messagesList.scrollToBottomDelayed();
            }

            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 16
            }

            IconImage {
                source: Quickshell.iconPath("draw-arrow-down")

                anchors {
                    fill: parent
                    margins: 4
                }
            }
        }
    }

    StyledRectangle {
        visible: ChatConnector.errorMessage !== ""
        color: "#7f1d1d"
        radius: 6

        Layout.fillWidth: true
        Layout.preferredHeight: errorText.implicitHeight + 12
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 8

        Text {
            id: errorText
            anchors.fill: parent
            anchors.margins: 6
            color: "#fecaca"
            text: ChatConnector.errorMessage
            wrapMode: Text.Wrap
            font.pixelSize: 12
        }
    }

    ChatTextBox {
        id: messageInput
        placeholderText: "Type a message..."
        busy: ChatConnector.busy
        supportsImages: ChatConnector.currentProvider?.supportsImages ?? false

        Layout.fillWidth: true
        Layout.margins: 8

        onAccepted: (message, images) => {
            ChatConnector.sendMessage(message, images);
            clear();
        }

        onStopRequested: ChatConnector.cancelRequest()
    }
}
