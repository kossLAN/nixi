pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.widgets
import qs.launcher

StyledMouseArea {
    id: root
    visible: ShellSettings.settings.searchEnabled
    onClicked: Launcher.launcherOpen = !Launcher.launcherOpen 

    IconImage {
        source: Quickshell.iconPath("search")

        anchors {
            fill: parent
                margins: 1
        }
    }
}
