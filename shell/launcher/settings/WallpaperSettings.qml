pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

import qs
import qs.widgets
import qs.filepicker

SettingsBacker {
    icon: "x-shape-image"

    summary: "Wallpaper Settings"
    label: "Wallpaper"

    content: Item {
        id: menu

        FilePicker {
            id: folderPicker
            folderMode: true

            onAccepted: ShellSettings.settings.wallpapersPath = selectedFile
        }

        ColumnLayout {
            spacing: 4

            anchors {
                fill: parent
                margins: 8
            }

            Item {
                Layout.preferredWidth: 160 * 2.3
                Layout.preferredHeight: 90 * 2.3
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 40

                RectangularShadow {
                    anchors.fill: preview
                    radius: preview.radius
                    blur: 16
                    spread: 2
                    color: Qt.rgba(0, 0, 0, 0.5)
                }

                ClippingRectangle {
                    id: preview
                    radius: 12
                    anchors.fill: parent

                    Image {
                        source: ShellSettings.settings.wallpaperUrl
                        anchors.fill: parent
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.topMargin: 40

                StyledButton {
                    color: ShellSettings.colors.active.base
                    radius: 8
                    implicitWidth: 32
                    implicitHeight: 32

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    onClicked: folderPicker.open()

                    IconImage {
                        source: Quickshell.iconPath("x-shape-image")

                        anchors {
                            fill: parent
                            margins: 2
                        }
                    }
                }
            }

            StyledRectangle {
                color: ShellSettings.colors.active.base
                radius: 8
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: wallpaperGrid
                    clip: true
                    cellWidth: width / 6
                    cellHeight: cellWidth

                    anchors {
                        fill: parent
                        margins: 8
                    }

                    model: FolderListModel {
                        id: builtinFolder
                        folder: ShellSettings.settings.wallpapersPath
                        nameFilters: ["*.jpg", "*.png", "*.jpeg", "*.webp"]
                    }

                    delegate: MouseArea {
                        id: wallpaper

                        required property string fileName
                        required property url filePath

                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        implicitWidth: wallpaperGrid.cellWidth
                        implicitHeight: wallpaperGrid.cellHeight

                        onClicked: ShellSettings.settings.wallpaperUrl = wallpaper.filePath

                        ClippingRectangle {
                            color: ShellSettings.colors.active.base
                            radius: 4

                            anchors {
                                fill: parent
                                margins: 4
                            }

                            Image {
                                source: Qt.resolvedUrl(wallpaper.filePath)
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                cache: false
                                asynchronous: true
                                anchors.fill: parent
                            }

                            Rectangle {
                                visible: wallpaper.containsMouse
                                color: "white"
                                opacity: 0.1
                                anchors.fill: parent
                            }
                        }
                    }
                }
            }
        }
    }
}
