import Quickshell

Scope {
    property string currentText: ""
    property string session: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string authMessage: ""
    signal unlocked
    signal failed
    signal tryUnlock

    onCurrentTextChanged: showFailure = false
}
