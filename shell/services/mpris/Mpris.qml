pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer trackedPlayer

    function hasTitle(player: MprisPlayer): bool {
        return (player.trackTitle ?? "").trim() !== "";
    }

    function updateSortedPlayers(): void {
        root.sortedPlayers = [...Mpris.players.values].filter(p => root.hasTitle(p)).sort((a, b) => {
            if (a === root.trackedPlayer)
                return -1;

            if (b === root.trackedPlayer)
                return 1;

            return 0;
        });
    }

    property list<MprisPlayer> sortedPlayers

    IpcHandler {
        target: "mpris"

        function next(): void {
            root.trackedPlayer.next();
        }

        function prev(): void {
            root.trackedPlayer.previous();
        }

        function play(): void {
            root.trackedPlayer.play();
        }

        function pause(): void {
            root.trackedPlayer.pause();
        }

        function play_pause(): void {
            if (root.trackedPlayer.isPlaying) {
                root.trackedPlayer.pause();
            } else {
                root.trackedPlayer.play();
            }
        }
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: {
                if (!root.hasTitle(modelData))
                    return;

                if (root.trackedPlayer == null || modelData.isPlaying) {
                    root.trackedPlayer = modelData;
                }

                root.updateSortedPlayers();
            }

            Component.onDestruction: {
                if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying) {
                    for (const player of Mpris.players.values) {
                        if (root.hasTitle(player) && player.playbackState === MprisPlaybackState.Playing) {
                            root.trackedPlayer = player;
                            break;
                        }
                    }

                    if (root.trackedPlayer == null && Mpris.players.values.length != 0) {
                        for (const player of Mpris.players.values) {
                            if (root.hasTitle(player)) {
                                root.trackedPlayer = player;
                                break;
                            }
                        }
                    }
                }

                root.updateSortedPlayers();
            }

            function onPlaybackStateChanged() {
                if (!root.hasTitle(modelData))
                    return;

                if (root.trackedPlayer !== modelData)
                    root.trackedPlayer = modelData;
            }

            function onTrackTitleChanged() {
                root.updateSortedPlayers();

                if (root.hasTitle(modelData)) {
                    if (root.trackedPlayer == null || modelData.isPlaying)
                        root.trackedPlayer = modelData;
                } else if (root.trackedPlayer === modelData) {
                    root.trackedPlayer = null;

                    for (const player of Mpris.players.values) {
                        if (root.hasTitle(player) && player.playbackState === MprisPlaybackState.Playing) {
                            root.trackedPlayer = player;
                            return;
                        }
                    }

                    for (const player of Mpris.players.values) {
                        if (root.hasTitle(player)) {
                            root.trackedPlayer = player;
                            return;
                        }
                    }
                }
            }
        }
    }

    function init() {
    }
}
