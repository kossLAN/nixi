pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs

Singleton {
    id: root

    property bool barEnabled: ShellSettings.settings.barEnabled

    IpcHandler {
        target: "bar"

        function show(): void {
            ShellSettings.settings.barEnabled = true;
        }

        function hide(): void {
            ShellSettings.settings.barEnabled = false;
        }

        function toggle(): void {
            ShellSettings.settings.barEnabled = !ShellSettings.settings.barEnabled;
        }
    }
}
