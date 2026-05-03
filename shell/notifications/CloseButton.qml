import QtQuick
import Quickshell

import qs
import qs.widgets

Item {
    id: root

    property int duration: 5000
    property bool paused: false

    signal clicked
    signal finished

    IconButton {
        source: Quickshell.iconPath("window-close")
        color: ShellSettings.colors.active.light
        hoverColor: ShellSettings.colors.extra.close
        onClicked: root.clicked()
        padding: 2

        anchors {
            fill: parent
            margins: 2
        }
    }

    Canvas {
        id: progressCircle

        property real progress: 1.0

        antialiasing: true
        anchors.fill: parent

        onProgressChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - 1;

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress);
            ctx.strokeStyle = ShellSettings.colors.active.highlight;
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }

    NumberAnimation {
        id: progressAnimation
        target: progressCircle
        property: "progress"
        from: 1.0
        to: 0.0
        duration: root.duration
        running: true
        easing.type: Easing.Linear

        paused: root.paused
        onFinished: root.finished()
    }
}
