pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import NixiUtils
import qs
import qs.notifications

Singleton {
    id: root

    readonly property string screenshotsDir: `${ShellSettings.homeDir}/Pictures/Screenshots`
    property string lastOutput: ""
    property bool isBusy: false
    property bool overlayActive: false

    property alias config: configAdapter.config

    FileView {
        id: configFile
        path: `${ShellSettings.homeDir}/.config/nixi/screenshot.json`
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: configAdapter

            property ScreenshotConfig config: ScreenshotConfig {}
        }
    }

    Screenshotter {
        id: shot

        onCaptureComplete: {
            if (root._regionMode) {
                root.overlayActive = true;
            } else {
                root._saveFullCapture();
            }
        }

        onCaptureError: message => {
            console.error("Screenshot capture error:", message);
            root.isBusy = false;
        }
    }

    property bool _regionMode: false

    Loader {
        id: overlayLoader
        active: root.overlayActive

        sourceComponent: Component {
            ScreenshotOverlay {
                screenshotPath: shot.imagePath
                screenshotWidth: shot.captureWidth
                screenshotHeight: shot.captureHeight
                screenRects: shot.screenRects

                onRegionSelected: (gx, gy, gw, gh, rc, ds, pathsJson, penW, penCol) => {
                    root.overlayActive = false;
                    root._saveRegion(gx, gy, gw, gh, rc, ds, pathsJson, penW, penCol);
                }

                onCancelled: {
                    root.overlayActive = false;
                    root.isBusy = false;
                }
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function capture(): void {
            root.captureScreen();
        }

        function region(): void {
            root.selectRegionAndCapture();
        }

        function status(): string {
            return JSON.stringify({
                busy: root.isBusy,
                lastOutput: root.lastOutput,
                screenshotsDir: root.screenshotsDir
            });
        }
    }

    property Component notification: NotificationBacker {
        id: toast
        summary: "Screenshot saved"
        showOnFullscreen: true
        iconSource: Quickshell.iconPath("gtk-fullscreen")

        body: Text {
            color: ShellSettings.colors.active.text.darker(1.25)
            font.pixelSize: 12
            font.weight: Font.Normal
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            maximumLineCount: 4
            text: root.lastOutput
        }

        icon: IconImage {
            source: Quickshell.iconPath("gtk-fullscreen")
            implicitSize: 36
        }

        buttons: CloseButton {
            paused: toast.hovered
            duration: 5000
            implicitHeight: 20
            implicitWidth: 20

            onFinished: toast.hide()
            onClicked: toast.discard()
        }
    }

    function _timestamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
    }

    function _destPath(): string {
        return `${root.screenshotsDir}/Screenshot_${root._timestamp()}.png`;
    }

    function _saveFullCapture(): void {
        let dest = root._destPath();

        if (shot.saveCropped(dest, 0, 0, -1, -1)) {
            root.lastOutput = dest;
            Notifications.createNotification(notification);
        } else {
            console.error("Screenshot: failed to save", dest);
        }

        root.isBusy = false;
    }

    function _saveRegion(x: int, y: int, w: int, h: int, roundCorners: bool, dropShadow: bool, pathsJson: string, penWidth: real, penColor: string): void {
        let dest = root._destPath();
        let ok = (pathsJson && pathsJson !== "[]") ? shot.saveWithAnnotation(dest, x, y, w, h, pathsJson, penWidth, penColor, roundCorners, dropShadow) : shot.saveCropped(dest, x, y, w, h, roundCorners, dropShadow);

        if (ok) {
            root.lastOutput = dest;
            Notifications.createNotification(notification);
        } else {
            console.error("Screenshot: failed to save region to", dest);
        }

        root.isBusy = false;
    }

    function captureScreen(): void {
        if (root.isBusy)
            return;
        root.isBusy = true;
        root._regionMode = false;
        shot.captureAll();
    }

    function selectRegionAndCapture(): void {
        if (root.isBusy)
            return;
        root.isBusy = true;
        root._regionMode = true;
        shot.captureAll();
    }

    function init(): void {
    }
}
