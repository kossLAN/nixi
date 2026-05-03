pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import org.kde.syntaxhighlighting

import qs
import qs.widgets
import qs.services.chat
import NixiUtils

Item {
    id: root

    required property string text
    property color textColor: ShellSettings.colors.active.text
    property color selectedTextColor: ShellSettings.colors.active.highlightedText
    property color selectionColor: ShellSettings.colors.active.highlight
    property int fontSize: 13

    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        width: root.width
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Image {
                source: ChatConnector.currentProvider?.icon ?? ""
                sourceSize.width: 16
                sourceSize.height: 16
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: source != ""
            }

            Text {
                text: ChatConnector.currentModel
                color: root.textColor
                font.pixelSize: root.fontSize
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: ScriptModel {
                objectProp: "id"

                values: {
                    let result = [];
                    let content = root.text;
                    // Split only on fenced code blocks; MarkdownView handles all
                    // math internally ($$, \[…\], \(…\), $…$) via MicroTeX.
                    let blockRegex = /```(\w*)\s*\n([\s\S]*?)```/g;
                    let lastIndex = 0;
                    let match;
                    let segmentId = 0;

                    while ((match = blockRegex.exec(content)) !== null) {
                        if (match.index > lastIndex) {
                            let textBefore = content.substring(lastIndex, match.index);
                            if (textBefore.trim()) {
                                result.push({
                                    id: segmentId++,
                                    type: "markdown",
                                    content: textBefore
                                });
                            }
                        }

                        result.push({
                            id: segmentId++,
                            type: "code",
                            language: match[1] || "",
                            content: match[2]
                        });

                        lastIndex = match.index + match[0].length;
                    }

                    if (lastIndex < content.length) {
                        let remaining = content.substring(lastIndex);
                        if (remaining.trim()) {
                            result.push({
                                id: segmentId++,
                                type: "markdown",
                                content: remaining
                            });
                        }
                    }

                    if (result.length === 0 && content.trim()) {
                        result.push({
                            id: segmentId++,
                            type: "markdown",
                            content: content
                        });
                    }

                    return result;
                }
            }

            delegate: Loader {
                id: segmentLoader

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.height : 0

                sourceComponent: modelData.type === "code" ? codeBlockComponent : markdownComponent

                Component {
                    id: markdownComponent

                    MarkdownView {
                        width: root.width
                        text: segmentLoader.modelData.content
                        color: root.textColor
                        fontSize: root.fontSize
                        selectionColor: root.selectionColor
                        selectedTextColor: root.selectedTextColor
                        selectByMouse: true
                    }
                }

                Component {
                    id: codeBlockComponent

                    StyledRectangle {
                        id: codeBlock

                        property string language: segmentLoader.modelData.language
                        property string code: segmentLoader.modelData.content.replace(/\n$/, "")
                        property bool copied: false

                        width: root.width
                        height: codeEdit.contentHeight + 16
                        color: Qt.darker(ShellSettings.colors.active.window, 1.2)
                        radius: 6

                        Flickable {
                            id: codeFlickable
                            clip: true
                            contentWidth: codeEdit.implicitWidth
                            contentHeight: codeEdit.contentHeight
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.horizontal: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            anchors {
                                fill: parent
                                margins: 8
                            }

                            TextEdit {
                                id: codeEdit
                                width: Math.max(implicitWidth, codeFlickable.width)
                                color: root.textColor
                                text: codeBlock.code
                                wrapMode: Text.NoWrap
                                font.family: "monospace"
                                font.pixelSize: root.fontSize - 1
                                textFormat: TextEdit.PlainText
                                readOnly: true
                                selectByMouse: true
                                selectedTextColor: root.selectedTextColor
                                selectionColor: root.selectionColor
                            }
                        }

                        StyledButton {
                            id: copyButton
                            width: 24
                            height: 24
                            radius: 4
                            color: Qt.darker(ShellSettings.colors.active.window, 1.4)

                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6

                            onClicked: {
                                Quickshell.clipboardText = codeBlock.code;
                                codeBlock.copied = true;
                                copyResetTimer.start();
                            }

                            IconImage {
                                source: Quickshell.iconPath(codeBlock.copied ? "check-filled" : "edit-copy")
                                anchors.fill: parent
                                anchors.margins: 4
                            }

                            Timer {
                                id: copyResetTimer
                                interval: 2000
                                onTriggered: codeBlock.copied = false
                            }
                        }

                        SyntaxHighlighter {
                            textEdit: codeEdit
                            definition: {
                                if (!codeBlock.language)
                                    return "";

                                let langMap = {
                                    "js": "JavaScript",
                                    "javascript": "JavaScript",
                                    "ts": "TypeScript",
                                    "typescript": "TypeScript",
                                    "py": "Python",
                                    "python": "Python",
                                    "rb": "Ruby",
                                    "ruby": "Ruby",
                                    "cpp": "C++",
                                    "c++": "C++",
                                    "c": "C",
                                    "cs": "C#",
                                    "csharp": "C#",
                                    "java": "Java",
                                    "go": "Go",
                                    "golang": "Go",
                                    "rs": "Rust",
                                    "rust": "Rust",
                                    "sh": "Bash",
                                    "bash": "Bash",
                                    "shell": "Bash",
                                    "zsh": "Zsh",
                                    "fish": "Fish",
                                    "json": "JSON",
                                    "yaml": "YAML",
                                    "yml": "YAML",
                                    "xml": "XML",
                                    "html": "HTML",
                                    "css": "CSS",
                                    "scss": "SCSS",
                                    "sass": "Sass",
                                    "less": "LESS",
                                    "sql": "SQL",
                                    "md": "Markdown",
                                    "markdown": "Markdown",
                                    "dockerfile": "Dockerfile",
                                    "docker": "Dockerfile",
                                    "make": "Makefile",
                                    "makefile": "Makefile",
                                    "cmake": "CMake",
                                    "qml": "QML",
                                    "lua": "Lua",
                                    "perl": "Perl",
                                    "php": "PHP",
                                    "swift": "Swift",
                                    "kotlin": "Kotlin",
                                    "kt": "Kotlin",
                                    "scala": "Scala",
                                    "r": "R",
                                    "julia": "Julia",
                                    "haskell": "Haskell",
                                    "hs": "Haskell",
                                    "elixir": "Elixir",
                                    "ex": "Elixir",
                                    "erlang": "Erlang",
                                    "erl": "Erlang",
                                    "clojure": "Clojure",
                                    "clj": "Clojure",
                                    "vim": "vim",
                                    "toml": "TOML",
                                    "ini": "INI Files",
                                    "diff": "Diff",
                                    "patch": "Diff",
                                    "nix": "Nix",
                                    "zig": "Zig",
                                    "latex": "LaTeX",
                                    "tex": "LaTeX"
                                };

                                let lang = codeBlock.language.toLowerCase();
                                return langMap[lang] || codeBlock.language;
                            }

                            theme: Repository.defaultTheme(Repository.DarkTheme)
                        }
                    }
                }
            }
        }
    }
}
