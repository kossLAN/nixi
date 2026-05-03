pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
    readonly property string folderName: "nixi"
    readonly property string folderPath: `${configHome}/${folderName}`

    readonly property string settingsPath: `${folderPath}/settings.json`
    readonly property string systemSettingsPath: `${folderPath}/system.json`

    property alias settings: userAdapter.settings
    property alias sizing: userAdapter.sizing
    property alias system: systemAdapter

    property QtObject colors: QtObject {
        property SystemPalette active: SystemPalette {
            colorGroup: SystemPalette.Active
        }

        property SystemPalette inactive: SystemPalette {
            colorGroup: SystemPalette.Inactive
        }

        property QtObject extra: QtObject {
            property color open: Qt.color("#4ade80")
            property color close: Qt.color("#FF474D")
        }
    }

    FileView {
        id: systemFile
        path: root.systemSettingsPath
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        blockLoading: true
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: systemAdapter

            property string session: ""
        }
    }

    FileView {
        id: userFile
        path: root.settingsPath
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: userAdapter

            property JsonObject settings: JsonObject {
                property string wallpaperUrl: ""
                property string wallpapersPath: `${root.homeDir}/.wallpapers`

                property bool barEnabled: true
                property bool bluetoothEnabled: false
                property bool searchEnabled: false
                property bool debugEnabled: false
                property bool gsrEnabled: false
                property bool chatEnabled: false
                property int chatContextMessages: 20

                property list<string> pinnedTray: ["power", "volume", "wifi", "bluetooth"]
            }

            property JsonObject sizing: JsonObject {
                property int barHeight: 22

                property JsonObject launcherPosition: JsonObject {
                    property real centerX: -1
                    property real y: -1
                }

                property JsonObject chatSize: JsonObject {
                    property real width: 950
                    property real height: 600
                }
            }
        }
    }
}
