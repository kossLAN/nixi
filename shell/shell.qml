//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import Quickshell
import QtQuick

import qs.bar
import qs.notifications
import qs.volosd
import qs.lockscreen
import qs.wallpaper
import qs.launcher
import qs.polkit

import qs.services.mpris
import qs.services.gsr
import qs.services.screenshot

ShellRoot {
    Bar {}
    Wallpaper {}
    VolumeOSD {}
    Polkit {}

    Component.onCompleted: {
        Notifications.init();
        Launcher.init();
        LockScreen.init();
        Mpris.init();
        GpuScreenRecord.init();
        Screenshot.init();
    }
}
