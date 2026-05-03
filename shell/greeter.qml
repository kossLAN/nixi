pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs
import qs.lockscreen

ShellRoot {
    id: root

    GreeterContext {
        id: context

        onLaunch: {
            lock.locked = false;
            Greetd.launch(context.state.session.split(","));
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            LockSurface {
                state: context.state
                wallpaper: "root:resources/general/greeter.jpg"
                showSessionSelector: true
                anchors.fill: parent
            }
        }
    }
}
