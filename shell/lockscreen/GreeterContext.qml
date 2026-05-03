import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import qs
import qs.lockscreen

Scope {
    id: root

    property LockState state: LockState {
        session: ShellSettings.system.session || Quickshell.env("GREETER_SESSION") || "start-hyprland"

        onSessionChanged: ShellSettings.system.session = session

        onTryUnlock: {
            this.unlockInProgress = true;

            Greetd.createSession(Quickshell.env("GREETER_USER") || "koss");
        }
    }

    signal launch

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
            if (responseRequired) {
                Greetd.respond(root.state.currentText);
            } else {
                root.state.authMessage = message;
            }
        }

        function onAuthFailure(message: string) {
            root.state.currentText = "";
            root.state.authMessage = message || "";
            root.state.failed();
            root.state.unlockInProgress = false;
        }

        function onReadyToLaunch() {
            root.state.unlockInProgress = false;
            root.state.authMessage = "";
            root.launch();
        }
    }
}
