pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs
import qs.widgets
import qs.services.chat
import qs.launcher.settings

SettingsBacker {
    icon: "applications-chat-panel"
    enabled: ShellSettings.settings.chatEnabled
    summary: "Chat Settings"
    label: "Chat"

    content: Item {
        id: menu

        ColumnLayout {
            spacing: 8
            anchors {
                fill: parent
                margins: 8
            }

            SettingsSection {
                title: "History"

                SettingsCard {
                    title: "Conversation History"
                    summary: `${ChatConnector.conversations.length} saved conversations`

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    controls: StyledButton {
                        implicitWidth: 110
                        implicitHeight: 28

                        onClicked: {
                            let convs = ChatConnector.conversations.slice();

                            for (let conv of convs) {
                                ChatConnector.deleteConversation(conv.id);
                            }
                        }

                        StyledText {
                            text: "Clear History"
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            anchors.fill: parent
                        }
                    }
                }

                Layout.fillWidth: true
            }

            Repeater {
                model: ChatConnector.providers

                SettingsSection {
                    id: providerSection

                    required property var modelData
                    required property int index

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        RowLayout {
                            spacing: 8

                            anchors.fill: parent

                            ProviderCard {
                                provider: providerSection.modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }

                            ToggleSwitch {
                                checked: providerSection.modelData.enabled

                                onCheckedChanged: {
                                    if (providerSection.modelData.enabled !== checked) {
                                        ChatConnector.setProviderEnabled(providerSection.modelData.providerId, checked);
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        active: providerSection.modelData.settings !== null
                        sourceComponent: providerSection.modelData.settings

                        Layout.fillWidth: true
                    }

                    Layout.fillWidth: true
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
