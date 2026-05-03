pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    property bool locked: false

    property LockState state: LockState {
        onTryUnlock: {
            if (this.currentText === "")
                return;

            this.unlockInProgress = true;
            pamPassword.start();
        }
    }

    function handleUnlock() {
        pamFingerprint.abort();
        pamPassword.abort();

        root.state.unlocked();
        root.state.currentText = "";
        root.state.unlockInProgress = false;
    }

    function startFingerprintAuth() {
        if (!pamFingerprint.active) {
            pamFingerprint.start();
        }
    }

    onLockedChanged: {
        if (locked) {
            startFingerprintAuth();
        } else {
            pamFingerprint.abort();
        }
    }

    PamContext {
        id: pamFingerprint

        configDirectory: "pam"
        config: "fingerprint.conf"

        Component.onCompleted: {
            if (root.locked) {
                this.start();
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.handleUnlock();
            } else if (root.locked) {
                root.startFingerprintAuth();
            }
        }
    }

    PamContext {
        id: pamPassword

        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.state.currentText);
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.handleUnlock();
            } else {
                root.state.showFailure = true;
                root.state.unlockInProgress = false;
            }
        }
    }
}
