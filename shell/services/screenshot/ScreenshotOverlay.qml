pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

import qs
import qs.widgets

Scope {
    id: root

    required property string screenshotPath
    required property int screenshotWidth
    required property int screenshotHeight
    required property string screenRects

    signal regionSelected(int imgX, int imgY, int imgW, int imgH, bool roundCorners, bool dropShadow, string pathsJson, real penWidth, string penColor)
    signal cancelled

    property bool selectionDone: false
    property rect finalSel: Qt.rect(0, 0, 0, 0)
    property var activeScreen: null

    property bool penMode: false
    property string penColor: "#ef4444"
    property real penWidth: 3

    property var penPaths: []
    property var currentPath: []

    property bool isDragging: false
    property point pressPos: Qt.point(0, 0)
    property point currentPos: Qt.point(0, 0)
    property var parsedScreenRects: {
        try {
            return JSON.parse(root.screenRects || "[]");
        } catch (error) {
            return [];
        }
    }

    function screenName(screen: var): string {
        return screen && screen.name ? screen.name : "";
    }

    function sourceRectFor(screen: var, width: real, height: real): var {
        const rects = root.parsedScreenRects || [];
        const name = root.screenName(screen);

        if (name) {
            for (const rect of rects) {
                if (rect.name === name)
                    return rect;
            }
        }

        for (const rect of rects) {
            if (Math.abs(rect.logicalW - width) <= 1 && Math.abs(rect.logicalH - height) <= 1)
                return rect;
        }

        return {
            imgX: 0,
            imgY: 0,
            imgW: root.screenshotWidth,
            imgH: root.screenshotHeight
        };
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData

            readonly property bool isActive: root.activeScreen === win.modelData

            screen: modelData
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: content
                anchors.fill: parent
                focus: true

                readonly property var sourceRect: root.sourceRectFor(win.modelData, win.width, win.height)
                readonly property real scaleX: sourceRect.imgW > 0 ? win.width / sourceRect.imgW : 1.0
                readonly property real scaleY: sourceRect.imgH > 0 ? win.height / sourceRect.imgH : 1.0

                readonly property rect sel: {
                    if (root.isDragging) {
                        return Qt.rect(Math.min(root.pressPos.x, root.currentPos.x), Math.min(root.pressPos.y, root.currentPos.y), Math.abs(root.currentPos.x - root.pressPos.x), Math.abs(root.currentPos.y - root.pressPos.y));
                    }
                    if (root.selectionDone && win.isActive)
                        return root.finalSel;
                    return Qt.rect(0, 0, 0, 0);
                }
                readonly property bool hasSel: sel.width > 0 && sel.height > 0

                Keys.onEscapePressed: root.cancelled()
                Keys.onReturnPressed: if (root.selectionDone && win.isActive)
                    content.confirm()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier) && root.penPaths.length > 0) {
                        root.penPaths = root.penPaths.slice(0, -1);
                        event.accepted = true;
                    }
                }

                function confirm() {
                    const sx = content.scaleX, sy = content.scaleY;
                    const fx = root.finalSel.x, fy = root.finalSel.y;
                    const src = content.sourceRect;

                    // Convert stroke points from window-space to crop-local image-space
                    const scaledPaths = root.penPaths.map(path => path.map(pt => ({
                                    x: (pt.x - fx) / sx,
                                    y: (pt.y - fy) / sy
                                })));

                    root.regionSelected(Math.round(src.imgX + fx / sx), Math.round(src.imgY + fy / sy), Math.round(root.finalSel.width / sx), Math.round(root.finalSel.height / sy), Screenshot.config.roundCorners, Screenshot.config.shadowEnabled, JSON.stringify(scaledPaths), root.penWidth / Math.min(sx, sy), root.penColor);
                }

                Item {
                    id: roundedScreenshot
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: roundedMask
                    }

                    Image {
                        anchors.fill: parent
                        source: root.screenshotPath
                        sourceClipRect: Qt.rect(content.sourceRect.imgX, content.sourceRect.imgY, content.sourceRect.imgW, content.sourceRect.imgH)
                        fillMode: Image.Stretch
                        smooth: true
                        cache: false
                        asynchronous: true
                        sourceSize.width: content.sourceRect.imgW
                        sourceSize.height: content.sourceRect.imgH
                    }
                }

                Rectangle {
                    id: roundedMask
                    anchors.fill: roundedScreenshot
                    radius: 12
                    visible: false
                    layer.enabled: true
                }

                readonly property color dimColor: Qt.rgba(0, 0, 0, 0.45)

                Rectangle {
                    color: content.dimColor
                    x: 0
                    y: 0
                    width: parent.width
                    height: content.hasSel ? content.sel.y : parent.height
                }
                Rectangle {
                    color: content.dimColor
                    x: 0
                    width: parent.width
                    y: content.hasSel ? content.sel.y + content.sel.height : parent.height
                    height: content.hasSel ? parent.height - (content.sel.y + content.sel.height) : 0
                }
                Rectangle {
                    color: content.dimColor
                    x: 0
                    y: content.hasSel ? content.sel.y : 0
                    width: content.hasSel ? content.sel.x : 0
                    height: content.hasSel ? content.sel.height : 0
                }
                Rectangle {
                    color: content.dimColor
                    x: content.hasSel ? content.sel.x + content.sel.width : parent.width
                    y: content.hasSel ? content.sel.y : 0
                    width: content.hasSel ? parent.width - (content.sel.x + content.sel.width) : 0
                    height: content.hasSel ? content.sel.height : 0
                }

                Shape {
                    anchors.fill: parent
                    visible: win.isActive && root.selectionDone

                    ShapePath {
                        strokeColor: root.penColor
                        strokeWidth: root.penWidth
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathMultiline {
                            paths: root.penPaths
                        }
                    }

                    ShapePath {
                        strokeColor: root.penColor
                        strokeWidth: root.penWidth
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: root.currentPath
                        }
                    }
                }

                Rectangle {
                    visible: content.hasSel
                    x: content.sel.x
                    y: content.sel.y
                    width: content.sel.width
                    height: content.sel.height
                    color: "transparent"
                    border.color: "white"
                    border.width: 2
                }

                MouseArea {
                    id: mainMa
                    anchors.fill: parent
                    cursorShape: (root.selectionDone && root.penMode && win.isActive) ? Qt.CrossCursor : (root.selectionDone ? Qt.ArrowCursor : Qt.CrossCursor)

                    onPressed: event => {
                        if (root.selectionDone) {
                            if (root.penMode && win.isActive) {
                                root.currentPath = [Qt.point(event.x, event.y)];
                                content.forceActiveFocus();
                            }
                        } else {
                            root.pressPos = Qt.point(event.x, event.y);
                            root.currentPos = root.pressPos;
                            root.isDragging = true;
                            root.activeScreen = win.modelData;
                            content.forceActiveFocus();
                        }
                    }

                    onPositionChanged: event => {
                        if (root.selectionDone) {
                            if (root.penMode && root.currentPath.length > 0 && win.isActive) {
                                const pts = root.currentPath.slice();
                                pts.push(Qt.point(event.x, event.y));
                                root.currentPath = pts;
                            }
                        } else if (root.isDragging) {
                            root.currentPos = Qt.point(event.x, event.y);
                        }
                    }

                    onReleased: {
                        if (root.selectionDone) {
                            if (root.penMode && root.currentPath.length > 1 && win.isActive) {
                                root.penPaths = root.penPaths.concat([root.currentPath]);
                                root.currentPath = [];
                            }
                        } else {
                            if (!root.isDragging)
                                return;
                            const sx = Math.min(root.pressPos.x, root.currentPos.x);
                            const sy = Math.min(root.pressPos.y, root.currentPos.y);
                            const sw = Math.abs(root.currentPos.x - root.pressPos.x);
                            const sh = Math.abs(root.currentPos.y - root.pressPos.y);
                            root.isDragging = false;

                            if (sw > 2 && sh > 2) {
                                root.finalSel = Qt.rect(sx, sy, sw, sh);
                                root.selectionDone = true;
                            } else {
                                root.cancelled();
                            }
                        }
                    }
                }

                Rectangle {
                    id: toolbar
                    visible: win.isActive && root.selectionDone

                    readonly property real tbW: tbRow.implicitWidth + 24
                    readonly property real tbH: 52
                    width: tbW
                    height: tbH

                    color: Qt.rgba(0.08, 0.08, 0.08, 0.88)
                    radius: 10
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    y: {
                        const below = root.finalSel.y + root.finalSel.height + 10;
                        return (below + tbH <= parent.height - 8) ? below : Math.max(8, root.finalSel.y - tbH - 10);
                    }
                    x: Math.max(8, Math.min(parent.width - tbW - 8, root.finalSel.x + (root.finalSel.width - tbW) / 2))

                    Row {
                        id: tbRow
                        anchors.centerIn: parent
                        spacing: 2

                        StyledButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            checked: root.penMode
                            hoverColor: ShellSettings.colors.active.highlight
                            onClicked: root.penMode = !root.penMode

                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("draw-freehand")
                                implicitSize: 18
                            }
                        }

                        StyledButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            checked: Screenshot.config.roundCorners
                            hoverColor: ShellSettings.colors.active.highlight
                            onClicked: Screenshot.config.roundCorners = !Screenshot.config.roundCorners

                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("transform-affect-rounded-corners")
                                implicitSize: 18
                            }
                        }

                        StyledButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            checked: Screenshot.config.shadowEnabled
                            hoverColor: ShellSettings.colors.active.highlight
                            onClicked: Screenshot.config.shadowEnabled = !Screenshot.config.shadowEnabled

                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("blurfx")
                                implicitSize: 18
                            }
                        }

                        StyledButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            onClicked: content.confirm()

                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("check-filled")
                                implicitSize: 18
                            }
                        }

                        StyledButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            onClicked: root.cancelled()

                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath("dialog-close")
                                implicitSize: 18
                            }
                        }
                    }
                }
            }
        }
    }
}
