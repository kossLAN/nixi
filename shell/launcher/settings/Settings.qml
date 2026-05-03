pragma ComponentBehavior: Bound

import QtQuick

import qs
import qs.launcher
import qs.widgets

import qs.launcher.settings.chat
import qs.launcher.settings.volume

LauncherBacker {
    id: root

    icon: "settings"

    switcherParent: switcherParent

    content: Item {
        id: menu
        implicitWidth: 900
        implicitHeight: 650

        SettingsManager {
            anchors {
                fill: parent
                // margins: 8
            }

            model: [
                GeneralSettings {},
                WallpaperSettings {},
                VolumeSettings {},
                WifiSettings {},
                BluetoothSettings {},
                ChatSettings {},
                GsrSettings {},
                DebugViewer {}
            ]
        }

        StyledRectangle {
            focus: true
            color: ShellSettings.colors.active.mid
            implicitHeight: switcherParent.implicitHeight + 8
            implicitWidth: switcherParent.implicitWidth + 8

            anchors {
                right: parent.right
                top: parent.top
                margins: 4
            }

            Item {
                id: switcherParent
                anchors.centerIn: parent
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }
}
