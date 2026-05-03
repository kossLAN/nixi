pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

import NixiUtils

import qs
import qs.widgets
import qs.filepicker

StyledRectangle {
    id: root

    clip: true
    radius: 8
    color: ShellSettings.colors.active.alternateBase

    property alias text: textInput.text
    property alias placeholderText: placeholder.text
    property bool busy: false
    property bool supportsImages: false

    // List of selected images as objects: [{base64: string, mediaType: string}]
    property var pendingImages: []

    // Dynamic height based on content
    readonly property int minHeight: 44
    readonly property int maxHeight: 200
    readonly property int imageRowHeight: root.pendingImages.length > 0 ? 60 : 0
    readonly property int contentAreaHeight: Math.max(28, textInput.contentHeight)

    signal accepted(string message, var images)
    signal stopRequested

    implicitHeight: Math.min(maxHeight, Math.max(minHeight, contentAreaHeight + 16 + imageRowHeight))
    height: implicitHeight

    function forceActiveFocus() {
        textInput.forceActiveFocus();
    }

    function clear() {
        textInput.text = "";
        pendingImages = [];
    }

    FilePicker {
        id: imageDialog
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif)", "All files (*)"]

        onAccepted: {
            let newImages = root.pendingImages.slice();

            newImages.push({
                base64: ClipboardUtils.fileToBase64(selectedFile),
                mediaType: ClipboardUtils.getMimeType(selectedFile)
            });

            root.pendingImages = newImages;
            textInput.forceActiveFocus();
        }

        onRejected: textInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Image preview
        Flow {
            visible: root.pendingImages.length > 0
            spacing: 6

            Layout.fillWidth: true

            Repeater {
                model: root.pendingImages

                Item {
                    id: imagePreview

                    required property var modelData
                    required property int index

                    width: 48
                    height: 48

                    ClippingRectangle {
                        color: "transparent"
                        radius: 6
                        anchors.fill: parent

                        Image {
                            source: "data:" + imagePreview.modelData.mediaType + ";base64," + imagePreview.modelData.base64
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            anchors.fill: parent
                        }
                    }

                    IconButton {
                        width: 16
                        height: 16
                        radius: height / 2
                        source: Quickshell.iconPath("window-close")
                        color: ShellSettings.colors.active.light
                        hoverColor: ShellSettings.colors.extra.close

                        onClicked: {
                            let newImages = root.pendingImages.slice();
                            newImages.splice(imagePreview.index, 1);
                            root.pendingImages = newImages;
                        }

                        anchors {
                            right: parent.right
                            top: parent.top
                            margins: -4
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flickable
                anchors.fill: parent
                anchors.rightMargin: buttonsRow.width + 6
                contentWidth: width
                contentHeight: textInput.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                // I wanted to use a TextArea or TextEdit, however it has tabStop which steals tab events
                // you can disable them, but not fully remove them
                TextInput {
                    id: textInput
                    width: flickable.width
                    color: ShellSettings.colors.active.text
                    focus: true
                    wrapMode: TextArea.Wrap
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: Math.max(0, (flickable.height - contentHeight) / 2)
                    bottomPadding: 0

                    Keys.onPressed: event => {
                        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_V) {
                            let base64 = ClipboardUtils.clipboardImage();
                            if (base64 === "") return;

                            let newImages = root.pendingImages.slice();

                            newImages.push({
                                base64: base64,
                                mediaType: "image/png"
                            });

                            root.pendingImages = newImages;
                        }
                    }

                    Keys.onReturnPressed: event => {
                        if (text.trim() !== "" && !root.busy) {
                            root.accepted(text.trim(), root.pendingImages);
                        }
                    }

                    Text {
                        id: placeholder
                        text: "Type a message..."
                        color: ShellSettings.colors.active.text
                        opacity: 0.5
                        visible: !textInput.text
                        anchors.left: parent.left
                        y: textInput.topPadding
                    }
                }
            }

            RowLayout {
                id: buttonsRow
                spacing: 4

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }

                // Stop button
                MouseArea {
                    id: stopButton
                    visible: root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.stopRequested()

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    IconImage {
                        id: stopIcon
                        source: Quickshell.iconPath("media-playback-stop")
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: false
                    }

                    ColorOverlay {
                        source: stopIcon
                        anchors.fill: stopIcon
                        color: {
                            if (stopButton.containsMouse)
                                return ShellSettings.colors.active.highlight;

                            return ShellSettings.colors.active.text;
                        }
                    }
                }

                // Image upload button
                MouseArea {
                    id: imageButton
                    visible: root.supportsImages
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: imageDialog.open()

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28

                    IconImage {
                        id: imageIcon
                        source: Quickshell.iconPath("clipboard")
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: imageIcon
                        source: imageIcon
                        color: {
                            if (imageButton.containsMouse)
                                return ShellSettings.colors.active.highlight;

                            return ShellSettings.colors.active.text;
                        }
                    }
                }
            }
        }
    }
}
