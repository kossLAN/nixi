pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.widgets
import qs.bar.tray

TrayBacker {
    id: root

    trayId: "volume"

    icon: Quickshell.iconPath(getIcon(root.sink)) 

    function getIcon(node) {
        if (!root.sink)
            return "audio-volume-low";

        if (root.sink.audio?.muted) {
            return "audio-volume-muted";
        } else if (root.sink.audio && root.sink.audio.volume > 0.66) {
            return "audio-volume-high";
        } else if (root.sink.audio && root.sink.audio.volume > 0.33) {
            return "audio-volume-medium";
        } else {
            return "audio-volume-low";
        }
    }

    property PwNode sink: Pipewire.defaultAudioSink

    button: StyledMouseArea {
        onClicked: root.clicked()

        IconImage {
            id: icon
            source: root.icon

            anchors {
                fill: parent
                margins: 2
            }
        }
    }

    menu: Item {
        id: menu
        implicitWidth: 300
        implicitHeight: container.implicitHeight + (2 * container.anchors.margins)

        property real entryHeight: 38

        ColumnLayout {
            id: container
            spacing: 2

            anchors {
                fill: parent
                margins: 4
            }

            // Default Audio
            VolumeCard {
                id: defaultCard
                node: root.sink
                Layout.fillWidth: true
                Layout.preferredHeight: menu.entryHeight

                leftWidget: StyledMouseArea {
                    enabled: defaultCard.node?.audio !== null && defaultCard.node?.audio !== undefined
                    onClicked: {
                        if (defaultCard.node?.audio) {
                            defaultCard.node.audio.muted = !defaultCard.node.audio.muted;
                        }
                    }

                    IconImage {
                        source: root.icon

                        anchors {
                            fill: parent
                            margins: 1
                        }
                    }
                }
            }

            // Application Mixer
            PwNodeLinkTracker {
                id: linkTracker
                node: root.sink
            }

            StyledListView {
                id: appList
                visible: linkTracker.linkGroups.length !== 0
                spacing: 2
                model: linkTracker.linkGroups
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: {
                    const entryHeight = Math.min(6, linkTracker.linkGroups.length);

                    return entryHeight * (menu.entryHeight + appList.spacing);
                }

                delegate: VolumeCard {
                    id: appCard
                    node: modelData?.source ?? null
                    label: appCard.node?.properties["media.name"] ?? ""
                    width: ListView.view.width
                    height: menu.entryHeight

                    required property PwLinkGroup modelData

                    leftWidget: StyledMouseArea {
                        enabled: appCard.node?.audio !== null && appCard.node?.audio !== undefined
                        onClicked: {
                            if (appCard.node?.audio) {
                                appCard.node.audio.muted = !appCard.node.audio.muted;
                            }
                        }

                        IconImage {
                            id: appIcon
                            visible: false

                            source: {
                                const props = appCard.node?.properties;
                                const fallbackIcon = "application-x-executable";

                                if (!props)
                                    return Quickshell.iconPath("application-x-executable");

                                if (props["application.icon-name"] !== undefined) {
                                    const iconName = props["application.icon-name"];
                                    const appEntryIcon = DesktopEntries.heuristicLookup(iconName)?.icon ?? "";

                                    return Quickshell.iconPath(appEntryIcon, iconName);
                                }

                                if (props["application.name"] !== undefined) {
                                    const applicationName = props["application.name"];
                                    const appEntryIcon = DesktopEntries.heuristicLookup(applicationName)?.icon ?? "";

                                    return Quickshell.iconPath(appEntryIcon, fallbackIcon);
                                }

                                return Quickshell.iconPath(fallbackIcon);
                            }

                            anchors {
                                fill: parent
                margins: 1
                            }
                        }

                        MultiEffect {
                            source: appIcon
                            anchors.fill: appIcon
                            saturation: appCard.node?.audio?.muted ? -1.0 : 0.0
                        }
                    }
                }
            }
        }
    }
}
