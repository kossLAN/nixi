pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import qs
import qs.notifications

Singleton {
    id: root

    readonly property string configPath: `${ShellSettings.folderPath}/gsr.json`
    readonly property string defaultOutputDir: `${ShellSettings.homeDir}/Videos`

    property alias config: gsrAdapter.config

    readonly property bool isRunning: config.enabled
    property bool isReplayMode: config.replayBufferSize > 0
    property string lastOutput: ""
    property string lastError: ""

    FileView {
        id: gsrFile
        path: root.configPath
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: gsrAdapter

            property GsrConfig config: GsrConfig {}
        }
    }

    Process {
        id: gsrProcess
        running: root.config.enabled
        command: root.buildCommand()

        onRunningChanged: {
            if (running) {
                root.lastOutput = "";
                root.lastError = "";
                console.log("GpuScreenRecord: Starting with command:", command.join(" "));
            }
        }

        stdout: SplitParser {
            splitMarker: ""

            onRead: data => {
                root.lastOutput += data;

                if (root.config.verbose) {
                    console.info("GSR stdout:", data.trim());
                }
            }
        }

        stderr: SplitParser {
            splitMarker: ""

            onRead: data => {
                root.lastError += data;

                if (ShellSettings.settings.debugEnabled) {
                    console.warn("GSR stderr:", data.trim());
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("GpuScreenRecord: Exited with code", exitCode, ":", root.lastError);
            } else {
                console.log("GpuScreenRecord: Process exited normally");
            }
        } 
    }

    Connections {
        target: Quickshell
        
        function onReloadCompleted() {
            // NOTE: currently if Quickshell reloads gsr-kms-server will be left a zombie
            // process, for now we just kill on a new gsr process 
            Quickshell.execDetached({
                command: ["pkill", "gsr-kms-server"]
            });
        }
    }

    IpcHandler {
        target: "gsr"

        function start(): void {
            root.start();
        }

        function stop(): void {
            root.stop();
        }

        function toggle(): void {
            root.toggle();
        }

        function save(): void {
            root.saveReplay();
        }

        function status(): string {
            return JSON.stringify({
                running: root.isRunning,
                replayMode: root.isReplayMode,
                config: {
                    window: root.config.window,
                    fps: root.config.fps,
                    codec: root.config.codec,
                    quality: root.config.quality,
                    replayBufferSize: root.config.replayBufferSize
                }
            });
        }
    }

    property Component notification: NotificationBacker {
        id: toast
        summary: "Clip saved"
        showOnFullscreen: true
        iconSource: Quickshell.iconPath("media-record")

        body: Text {
            color: ShellSettings.colors.active.text.darker(1.25)
            font.pixelSize: 12
            font.weight: Font.Normal
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            maximumLineCount: 4

            text: `The last ${root.config.replayBufferSize} seconds has been saved.`
        }

        icon: IconImage {
            source: Quickshell.iconPath("media-record")
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

    function buildCommand(): list<string> {
        let cmd = ["gpu-screen-recorder"];
        let cfg = config;

        // window/capture target
        cmd.push("-w", cfg.window);

        // Container format
        if (cfg.containerFormat !== "") {
            cmd.push("-c", cfg.containerFormat);
        }

        // Output size (optional, for scaling)
        if (cfg.size !== "") {
            cmd.push("-s", cfg.size);
        }

        // Region (for -w region)
        if (cfg.region !== "" && cfg.window === "region") {
            cmd.push("-region", cfg.region);
        }

        cmd.push("-f", cfg.fps.toString());

        if (cfg.audioInput !== "") {
            let audioInputs = cfg.audioInput.split(",");

            for (let input of audioInputs) {
                let trimmed = input.trim();

                if (trimmed !== "") {
                    cmd.push("-a", trimmed);
                }
            }
        }

        // Quality
        cmd.push("-q", cfg.quality);

        // Replay buffer (0 = recording mode)
        if (cfg.replayBufferSize > 0) {
            cmd.push("-r", cfg.replayBufferSize.toString());
            cmd.push("-replay-storage", cfg.replayStorage);
            cmd.push("-restart-replay-on-save", cfg.restartReplayOnSave ? "yes" : "no");
        }

        // Video codec
        cmd.push("-k", cfg.codec);

        // Audio codec
        cmd.push("-ac", cfg.audioCodec);

        // Audio bitrate
        if (cfg.audioBitrate > 0) {
            cmd.push("-ab", cfg.audioBitrate.toString());
        }

        // Overclock (NVIDIA)
        cmd.push("-oc", cfg.overclock ? "yes" : "no");

        // Framerate mode
        cmd.push("-fm", cfg.framerateMode);

        // Bitrate mode
        cmd.push("-bm", cfg.bitrateMode);

        // Color range
        cmd.push("-cr", cfg.colorRange);

        // Tune
        cmd.push("-tune", cfg.tune);

        // Date folder
        cmd.push("-df", cfg.dateFolder ? "yes" : "no");

        // Script path
        if (cfg.scriptPath !== "") {
            cmd.push("-sc", cfg.scriptPath);
        }

        // Plugin path
        if (cfg.pluginPath !== "") {
            cmd.push("-p", cfg.pluginPath);
        }

        // Cursor
        cmd.push("-cursor", cfg.cursor ? "yes" : "no");

        // Keyframe interval
        cmd.push("-keyint", cfg.keyint.toString());

        // Portal session restore
        cmd.push("-restore-portal-session", cfg.restorePortalSession ? "yes" : "no");

        // Portal session token path
        if (cfg.portalSessionTokenPath !== "") {
            cmd.push("-portal-session-token-filepath", cfg.portalSessionTokenPath);
        }

        // Encoder
        cmd.push("-encoder", cfg.encoder);

        // Fallback CPU encoding
        cmd.push("-fallback-cpu-encoding", cfg.fallbackCpuEncoding ? "yes" : "no");

        // Output file path
        let ext = cfg.containerFormat !== "" ? cfg.containerFormat : "mp4";
        let outputDir = cfg.replayOutputDir !== "" ? cfg.replayOutputDir : root.defaultOutputDir;

        if (cfg.replayBufferSize > 0) {
            // Replay mode: -o takes a directory, GSR adds timestamp and extension
            cmd.push("-o", outputDir);
        } else {
            // Recording mode
            if (cfg.outputFile !== "") {
                cmd.push("-o", cfg.outputFile);
            } else {
                let timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
                cmd.push("-o", `${outputDir}/Recording_${timestamp}.${ext}`);
            }
        }

        // FFmpeg options
        if (cfg.ffmpegOpts !== "") {
            cmd.push("-ffmpeg-opts", cfg.ffmpegOpts);
        }

        // Low power mode
        cmd.push("-low-power", cfg.lowPower ? "yes" : "no");

        // Verbose
        cmd.push("-v", cfg.verbose ? "yes" : "no");

        return cmd;
    }

    function start(): void {
        root.config.enabled = true;
    }

    function stop(): void {
        root.config.enabled = false;
    }

    function saveReplay(): void {
        if (!gsrProcess.running) {
            console.warn("GpuScreenRecord: Not running, cannot save replay");
            return;
        }

        if (!root.isReplayMode) {
            console.warn("GpuScreenRecord: Not in replay mode");
            return;
        }

        gsrProcess.signal(10);
        Notifications.createNotification(notification)

        console.log("GpuScreenRecord: Replay save triggered");
    }

    function toggle(): void {
        root.config.enabled = !root.config.enabled;
    }

    function init(): void {
    }
}
