import QtQuick
import qs

StyledRectangle {
    id: root

    clip: true
    radius: 6
    color: ShellSettings.colors.active.alternateBase
    implicitHeight: 28

    property alias text: textInput.text
    property alias placeholderText: placeholder.text
    property alias echoMode: textInput.echoMode
    property bool isSensitive: false
    property bool shaking: false

    signal accepted

    function forceActiveFocus() {
        textInput.forceActiveFocus();
    }

    function clear() {
        textInput.text = "";
    }

    onShakingChanged: {
        if (shaking && isSensitive)
            shakeAnimation.start();
    }

    transform: Translate {
        id: shakeTransform
        x: 0
    }

    Item {
        // clip: true

        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }

        TextInput {
            id: textInput
            color: ShellSettings.colors.active.text
            clip: true
            focus: true
            verticalAlignment: TextInput.AlignVCenter
            echoMode: root.isSensitive ? TextInput.Password : TextInput.Normal
            inputMethodHints: root.isSensitive ? Qt.ImhSensitiveData : Qt.ImhNone
            scale: root.isSensitive && activeFocus ? 1.02 : 1.0
            anchors.fill: parent

            onAccepted: root.accepted()

            Behavior on scale {
                enabled: root.isSensitive

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: placeholder
                color: ShellSettings.colors.active.text
                opacity: 0.5
                visible: !textInput.text
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            target: shakeTransform
            property: "x"
            to: -8
            duration: 50
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: shakeTransform
            property: "x"
            to: 8
            duration: 100
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shakeTransform
            property: "x"
            to: -6
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shakeTransform
            property: "x"
            to: 6
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: shakeTransform
            property: "x"
            to: -3
            duration: 60
            easing.type: Easing.InOutQuad
        }

        onFinished: {
            root.shaking = false;
            root.clear();
        }
    }
}
