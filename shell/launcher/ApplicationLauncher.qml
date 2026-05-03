import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets
import qs.services.nix

LauncherBacker {
    id: root

    signal accepted

    icon: "search"
    switcherParent: switcherParent

    content: WrapperItem {
        id: menu
        margin: 6

        property alias currentIndex: list.currentIndex
        property alias currentItem: list.currentItem
        property var matchesLength: list.model.values.length
        readonly property real delegateHeight: list.delegateHeight

        // Nix search mode
        readonly property bool nixMode: search.text.startsWith("!nix ")
        readonly property string nixQuery: nixMode ? search.text.slice(5).trim() : ""
        property var nixPackages: []
        property bool nixLoading: false
        property string nixOutput: ""

        Timer {
            id: nixSearchDebounce
            interval: 400
            repeat: false
            onTriggered: {
                if (menu.nixQuery !== "") {
                    menu.nixLoading = true;
                    menu.nixPackages = [];
                    nixSearchProcess.running = true;
                }
            }
        }

        onNixQueryChanged: {
            if (nixQuery === "") {
                menu.nixPackages = [];
                menu.nixLoading = false;
            } else {
                nixSearchDebounce.restart();
            }
        }

        Process {
            id: nixSearchProcess
            command: ["nix", "search", "nixpkgs", menu.nixQuery, "--json"]

            stderr: SplitParser {
                onRead: data => {}
            }

            stdout: SplitParser {
                splitMarker: ""
                onRead: data => menu.nixOutput += data
            }

            onExited: (exitCode, exitStatus) => {
                menu.nixLoading = false;

                if (menu.nixOutput !== "") {
                    try {
                        let parsed = JSON.parse(menu.nixOutput);
                        let packages = [];

                        for (let key in parsed) {
                            let pkg = parsed[key];
                            let attrName = key.split(".").slice(2).join(".");

                            packages.push({
                                attr: attrName,
                                pname: pkg.pname || attrName,
                                version: pkg.version || "",
                                description: pkg.description || ""
                            });
                        }

                        let query = menu.nixQuery.toLowerCase();

                        packages.sort((a, b) => {
                            let aExact = a.pname.toLowerCase() === query || a.attr.toLowerCase() === query;
                            let bExact = b.pname.toLowerCase() === query || b.attr.toLowerCase() === query;

                            if (aExact && !bExact)
                                return -1;

                            if (bExact && !aExact)
                                return 1;

                            let aStarts = a.pname.toLowerCase().startsWith(query) || a.attr.toLowerCase().startsWith(query);
                            let bStarts = b.pname.toLowerCase().startsWith(query) || b.attr.toLowerCase().startsWith(query);

                            if (aStarts && !bStarts)
                                return -1;

                            if (bStarts && !aStarts)
                                return 1;

                            return a.attr.length - b.attr.length;
                        });

                        menu.nixPackages = packages.slice(0, 50);
                    } catch (e) {
                        console.error("Failed to parse nix search output:", e);
                        menu.nixPackages = [];
                    }
                } else {
                    menu.nixPackages = [];
                }

                menu.nixOutput = "";
            }

            onStarted: {
                menu.nixOutput = "";
            }
        }

        function runNixPackage(attrName: string): void {
            // Notifications.runNixPackage(attrName);
            NixRunner.runNixPackage(attrName);
            root.accepted();
        }

        ColumnLayout {
            spacing: 6

            StyledRectangle {
                id: searchContainer

                color: ShellSettings.colors.active.alternateBase
                radius: 8

                Layout.preferredWidth: 525
                Layout.preferredHeight: 35

                RowLayout {
                    id: searchbox
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 8

                    IconImage {
                        visible: menu.nixMode
                        source: Quickshell.iconPath("nix-snowflake")
                        implicitSize: 22

                        Layout.leftMargin: 4
                        Layout.alignment: Qt.AlignVCenter

                        SequentialAnimation on opacity {
                            running: menu.nixLoading
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 1.0
                                to: 0.3
                                duration: 800
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                from: 0.3
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    Item {
                        clip: true

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.leftMargin: menu.nixMode ? -prefixWidth : 4
                            color: ShellSettings.colors.active.text
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true

                            property real prefixWidth: nixPrefixMetrics.advanceWidth

                            TextMetrics {
                                id: nixPrefixMetrics
                                font: search.font
                                text: "!nix "
                            }

                            Keys.forwardTo: [list]

                            onTextChanged: list.currentIndex = 0

                            onAccepted: {
                                if (list.currentItem) {
                                    list.currentItem.activate();
                                } else if (menu.nixMode && menu.nixQuery !== "") {
                                    menu.runNixPackage(menu.nixQuery);
                                }
                            }
                        }
                    }

                    Item {
                        id: switcherParent

                        Layout.preferredHeight: childrenRect.height
                        Layout.preferredWidth: childrenRect.width
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            StyledListView {
                id: list

                readonly property real delegateHeight: 52
                readonly property int maxVisibleItems: 9

                visible: Layout.preferredHeight > 1
                clip: true
                cacheBuffer: 0 // works around QTBUG-131106

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(model.values.length, maxVisibleItems) * delegateHeight

                model: ScriptModel {
                    objectProp: menu.nixMode ? "name" : ""

                    values: {
                        if (menu.nixMode) {
                            return menu.nixPackages.map(pkg => ({
                                        name: pkg.attr,
                                        description: pkg.description,
                                        icon: pkg.pname,
                                        version: pkg.version,
                                        isNix: true,
                                        nixAttr: pkg.attr
                                    }));
                        }

                        const stxt = search.text.toLowerCase();

                        if (stxt === '')
                            return [];

                        return DesktopEntries.applications.values.map(object => {
                            const ntxt = object.name.toLowerCase();
                            let si = 0;
                            let ni = 0;

                            let matches = [];
                            let startMatch = -1;

                            for (let si = 0; si != stxt.length; ++si) {
                                const sc = stxt[si];

                                while (true) {
                                    // Drop any entries with letters that don't exist in order
                                    if (ni == ntxt.length)
                                        return null;

                                    const nc = ntxt[ni++];

                                    if (nc == sc) {
                                        if (startMatch == -1)
                                            startMatch = ni;
                                        break;
                                    } else {
                                        if (startMatch != -1) {
                                            matches.push({
                                                index: startMatch,
                                                length: ni - startMatch
                                            });

                                            startMatch = -1;
                                        }
                                    }
                                }
                            }

                            if (startMatch != -1) {
                                matches.push({
                                    index: startMatch,
                                    length: ni - startMatch + 1
                                });
                            }

                            return {
                                object: object,
                                matches: matches
                            };
                        }).filter(entry => entry !== null).sort((a, b) => {
                            let ai = 0;
                            let bi = 0;
                            let s = 0;

                            while (ai != a.matches.length && bi != b.matches.length) {
                                const am = a.matches[ai];
                                const bm = b.matches[bi];

                                s = bm.length - am.length;
                                if (s != 0)
                                    return s;

                                s = am.index - bm.index;
                                if (s != 0)
                                    return s;

                                ++ai;
                                ++bi;
                            }

                            s = a.matches.length - b.matches.length;
                            if (s != 0)
                                return s;

                            s = a.object.name.length - b.object.name.length;
                            if (s != 0)
                                return s;

                            return a.object.name.localeCompare(b.object.name);
                        }).map(entry => entry.object);
                    }
                }

                highlight: Rectangle {
                    radius: 6
                    color: ShellSettings.colors.active.accent
                }

                keyNavigationEnabled: true
                keyNavigationWraps: true
                highlightMoveVelocity: -1
                highlightMoveDuration: 100
                preferredHighlightBegin: list.topMargin
                preferredHighlightEnd: list.height - list.bottomMargin
                highlightRangeMode: ListView.ApplyRange
                snapMode: ListView.SnapToItem

                delegate: MouseArea {
                    id: entryMouseArea

                    required property var modelData
                    required property int index

                    readonly property bool isNix: modelData.isNix ?? false
                    readonly property string entryName: isNix ? modelData.name : modelData.name
                    readonly property string entryDescription: isNix ? (modelData.description ?? "") : (modelData.comment ?? "")
                    readonly property string entryIcon: isNix ? modelData.icon : modelData.icon
                    readonly property string entryVersion: isNix ? (modelData.version ?? "") : ""

                    implicitHeight: list.delegateHeight
                    implicitWidth: ListView.view.width

                    function activate(): void {
                        if (isNix) {
                            menu.runNixPackage(modelData.nixAttr);
                        } else {
                            modelData.execute();
                            root.accepted();
                        }
                    }

                    onClicked: activate()

                    RowLayout {
                        spacing: 10

                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: 5
                        }

                        IconImage {
                            asynchronous: true
                            implicitSize: 30
                            source: Quickshell.iconPath(entryMouseArea.entryIcon, "application-x-executable")
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledText {
                                    text: entryMouseArea.entryName
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    visible: entryMouseArea.entryVersion !== ""
                                    text: entryMouseArea.entryVersion
                                    opacity: 0.6
                                    font.pixelSize: 11
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            StyledText {
                                visible: entryMouseArea.entryDescription !== ""
                                text: entryMouseArea.entryDescription
                                opacity: 0.7
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
