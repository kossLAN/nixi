import Quickshell
import QtQuick

import qs
import qs.widgets

StyledText {
    id: text
    color: ShellSettings.colors.active.windowText
    text: `${hours}:${minutes} ${ap}`
    font.pointSize: ShellSettings.sizing.barHeight / 2.5
    verticalAlignment: Text.AlignVCenter

    property string ap: sysClock.hours >= 12 ? "PM" : "AM"
    property string minutes: sysClock.minutes.toString().padStart(2, '0')
    property string hours: {
        var value = sysClock.hours % 12;

        if (value === 0)
            return 12;

        return value;
    }

    SystemClock {
        id: sysClock
        enabled: true
    }
}
