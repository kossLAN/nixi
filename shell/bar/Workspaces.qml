pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.WindowManager
import qs
import qs.widgets

Item {
    id: root

    required property var screen

    readonly property var screenProj: WindowManager.screenProjection(root.screen)
    readonly property real workspaceFontPointSize: ShellSettings.sizing.barHeight / 2.5
    readonly property int workspaceIndicatorHeight: Math.max(2, Math.round(ShellSettings.sizing.barHeight / 8))
    readonly property int workspacePadding: 8

    readonly property var sortedWorkspaces: {
        if (!screenProj?.windowsets?.length)
            return [];

        return [...screenProj.windowsets].sort((a, b) => (a.coordinates?.[0] ?? 0) - (b.coordinates?.[0] ?? 0));
    }

    function activeWorkspaceIndex() {
        for (let i = 0; i < sortedWorkspaces.length; ++i) {
            if (sortedWorkspaces[i].active)
                return i;
        }

        return -1;
    }

    function syncCurrentWorkspace() {
        const activeIndex = activeWorkspaceIndex();

        if (activeIndex >= 0)
            workspaceList.currentIndex = activeIndex;
    }

    function workspaceLabel(workspace, index) {
        if (!workspace)
            return "";

        const label = workspace.name ?? workspace.title ?? workspace.idx ?? workspace.id;

        if (label !== undefined && label !== null && `${label}` !== "")
            return `${label}`;

        return `${(workspace.coordinates?.[0] ?? index) + 1}`;
    }

    StyledListView {
        id: workspaceList
        anchors.fill: parent
        clip: true
        orientation: ListView.Horizontal
        spacing: 0
        interactive: false

        highlightFollowsCurrentItem: true
        highlightMoveVelocity: -1
        highlightMoveDuration: 200
        highlightRangeMode: ListView.ApplyRange
        snapMode: ListView.SnapToItem

        preferredHighlightBegin: 0
        preferredHighlightEnd: width

        onCountChanged: root.syncCurrentWorkspace()
        Component.onCompleted: root.syncCurrentWorkspace()

        model: ScriptModel {
            values: root.sortedWorkspaces
        }

        highlight: Item {
            id: workspaceIndicator

            visible: workspaceList.currentIndex >= 0
            width: workspaceList.currentItem ? workspaceList.currentItem.width : 0
            height: workspaceList.height

            function indicatorWidth() {
                if (!workspaceList.currentItem)
                    return 0;

                return Math.max(0, workspaceList.currentItem.width - (root.workspacePadding / 2));
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }

                width: workspaceIndicator.indicatorWidth()
                height: root.workspaceIndicatorHeight
                radius: height / 2
                color: ShellSettings.colors.active.accent
            }
        }

        delegate: StyledMouseArea {
            id: workspaceButton

            required property var modelData
            required property int index

            readonly property bool isActive: modelData.active
            readonly property bool isCurrent: ListView.isCurrentItem

            checked: false
            hoverColor: isCurrent ? "transparent" : ShellSettings.colors.inactive.accent
            color: "transparent"
            radius: 0

            implicitHeight: ListView.view.height
            implicitWidth: Math.max(ListView.view.height, workspaceName.implicitWidth + root.workspacePadding)

            onClicked: workspaceButton.modelData.activate()
            onIsActiveChanged: {
                if (isActive)
                    workspaceList.currentIndex = workspaceButton.index;
            }

            Component.onCompleted: {
                if (isActive)
                    workspaceList.currentIndex = workspaceButton.index;
            }

            Text {
                id: workspaceName
                anchors.fill: parent
                color: ShellSettings.colors.active.text
                font.pointSize: root.workspaceFontPointSize
                horizontalAlignment: Text.AlignHCenter
                text: root.workspaceLabel(workspaceButton.modelData, workspaceButton.index)
                renderType: Text.NativeRendering
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
