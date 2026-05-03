pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.widgets
import qs.services.chat
import qs.launcher.settings

ChatProvider {
    id: root

    enabled: true
    name: "Anthropic"
    icon: "root:resources/chat/claude.svg"
    providerId: "anthropic"
    apiEndpoint: "https://api.anthropic.com"

    property string apiVersion: "2023-06-01"
    property string authHeader: "x-api-key"
    property string authPrefix: ""

    property string apiKey: ""

    available: false
    supportsImages: true

    settings: ColumnLayout {
        spacing: 4

        SettingsCard {
            title: "API Key"
            summary: "Your Anthropic API key"

            controls: StyledTextInput {
                text: root.apiKey
                width: 250
                placeholderText: "Enter your API key"
                echoMode: TextInput.Password

                onAccepted: {
                    ChatConnector.setProviderApiKey(root.providerId, text);
                    root.apiKey = text;
                    root.checkAvailability();
                }
            }

            Layout.fillWidth: true
            Layout.preferredHeight: 36
        }
    }

    property var _chatRequest: null
    property int _lastProcessedIndex: 0

    function _processStreamingResponse(): void {
        if (!_chatRequest)
            return;

        let responseText = _chatRequest.responseText;
        if (responseText.length <= _lastProcessedIndex)
            return;

        let newData = responseText.substring(_lastProcessedIndex);
        let lines = newData.split("\n");

        for (let i = 0; i < lines.length - 1; i++) {
            let line = lines[i].trim();
            if (line === "")
                continue;

            if (line.startsWith("data: ")) {
                let jsonStr = line.substring(6);
                if (jsonStr === "[DONE]") {
                    root.busy = false;
                    root.responseComplete(root.currentResponse);
                    root._chatRequest = null;
                    return;
                }

                try {
                    let event = JSON.parse(jsonStr);

                    if (event.type === "content_block_delta") {
                        if (event.delta?.type === "text_delta" && event.delta?.text) {
                            let chunk = event.delta.text;
                            root.currentResponse += chunk;
                            root.responseChunk(chunk);
                        }
                    }

                    if (event.type === "message_stop") {
                        root.busy = false;
                        root.responseComplete(root.currentResponse);
                        root._chatRequest = null;
                        return;
                    }

                    if (event.type === "error") {
                        root.busy = false;
                        root.errorMessage = event.error?.message || "Unknown error";
                        root.responseError(root.errorMessage);
                        root._chatRequest = null;
                        return;
                    }
                } catch (e) {}
            }
        }

        let lastNewlineIndex = newData.lastIndexOf("\n");
        if (lastNewlineIndex >= 0) {
            _lastProcessedIndex += lastNewlineIndex + 1;
        }
    }

    function fetchModels(): void {
        if (root.apiKey === "") {
            root.models = [];
            root.available = false;
            return;
        }

        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let modelNames = [];

                        if (response.data && Array.isArray(response.data)) {
                            for (let model of response.data) {
                                if (model.id) {
                                    modelNames.push(model.id);
                                }
                            }
                        }

                        if (modelNames.length > 0) {
                            root.models = modelNames;
                        }

                        root.available = modelNames.length > 0;

                        if (modelNames.length > 0 && root.currentModel === "") {
                            root.currentModel = modelNames[0];
                        }

                        root.modelsLoaded(modelNames);
                        root.errorMessage = "";
                    } catch (e) {
                        console.error("Anthropic: Failed to parse models response:", e);
                        root.errorMessage = "Failed to parse models response";
                        root.available = false;
                    }
                } else {
                    root.available = false;
                    root.errorMessage = "Failed to fetch models";
                }
            }
        };

        xhr.open("GET", `${root.apiEndpoint}/v1/models`);
        xhr.setRequestHeader("x-api-key", root.apiKey);
        xhr.setRequestHeader("anthropic-version", root.apiVersion);
        xhr.send();
    }

    function _buildContentArray(text, images) {
        let content = [];

        content.push({
            type: "text",
            text: text
        });

        if (images && Array.isArray(images)) {
            for (let img of images) {
                content.push({
                    type: "image",
                    source: {
                        type: "base64",
                        media_type: img.mediaType,
                        data: img.base64
                    }
                });
            }
        }

        return content;
    }

    function sendMessage(message, history, images = null) {
        if (root.busy) {
            console.warn("Anthropic: Already processing a request");
            return;
        }

        if (root.currentModel === "") {
            root.errorMessage = "No model selected";
            root.responseError(root.errorMessage);
            return;
        }

        if (root.apiKey === "") {
            root.errorMessage = "No API key";
            root.responseError(root.errorMessage);
            return;
        }

        root.busy = true;
        root.currentResponse = "";
        root.errorMessage = "";
        root._lastProcessedIndex = 0;

        let messages = [];

        if (history && Array.isArray(history)) {
            for (let msg of history) {
                if (msg.images && Array.isArray(msg.images) && msg.images.length > 0) {
                    messages.push({
                        role: msg.role,
                        content: _buildContentArray(msg.content, msg.images)
                    });
                } else {
                    messages.push({
                        role: msg.role,
                        content: msg.content
                    });
                }
            }
        }

        if (images && Array.isArray(images) && images.length > 0) {
            messages.push({
                role: "user",
                content: _buildContentArray(message, images)
            });
        } else {
            messages.push({
                role: "user",
                content: message
            });
        }

        let payload = {
            model: root.currentModel,
            messages: messages,
            stream: true,
            max_tokens: 4096
        };

        let xhr = new XMLHttpRequest();
        root._chatRequest = xhr;

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.LOADING) {
                root._processStreamingResponse();
            }

            if (xhr.readyState === XMLHttpRequest.DONE) {
                root._processStreamingResponse();

                if (xhr.status !== 200 && root.busy) {
                    root.busy = false;
                    let errorMsg = "Chat request failed";
                    try {
                        let errResponse = JSON.parse(xhr.responseText);
                        if (errResponse.error?.message) {
                            errorMsg = errResponse.error.message;
                        }
                    } catch (e) {}
                    root.errorMessage = errorMsg;
                    root.responseError(errorMsg);
                } else if (root.busy && root.currentResponse !== "") {
                    root.busy = false;
                    root.responseComplete(root.currentResponse);
                }

                root._chatRequest = null;
            }
        };

        xhr.open("POST", `${root.apiEndpoint}/v1/messages`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("x-api-key", root.apiKey);
        xhr.setRequestHeader("anthropic-version", root.apiVersion);
        xhr.send(JSON.stringify(payload));
    }

    function cancelRequest(): void {
        if (root._chatRequest) {
            root._chatRequest.abort();
            root._chatRequest = null;
            root.busy = false;
            root.errorMessage = "Request cancelled";
        }
    }

    function generateTitle(userMessage, assistantResponse, callback): void {
        if (root.apiKey === "" || root.currentModel === "")
            return;

        let prompt = `Summarize the following conversation in 5 words or fewer. Reply with only the title, no quotes, no punctuation.\n\nUser: ${userMessage}\nAssistant: ${assistantResponse}`;

        let payload = {
            model: root.currentModel,
            messages: [
                {
                    role: "user",
                    content: prompt
                }
            ],
            stream: false,
            max_tokens: 32
        };

        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let title = (response.content?.[0]?.text ?? "").trim();
                        if (title !== "")
                            callback(title);
                    } catch (e) {
                        console.warn("Anthropic: Failed to parse title response:", e);
                    }
                }
            }
        };

        xhr.open("POST", `${root.apiEndpoint}/v1/messages`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("x-api-key", root.apiKey);
        xhr.setRequestHeader("anthropic-version", root.apiVersion);
        xhr.send(JSON.stringify(payload));
    }

    function checkAvailability(): void {
        if (root.apiKey !== "") {
            root.fetchModels();
        }
    }
}
