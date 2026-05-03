pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.widgets
import qs.services.chat
import qs.launcher.settings

ChatProvider {
    id: root

    enabled: true
    name: "Ollama"
    icon: "root:resources/chat/ollama.png"
    providerId: "ollama"
    apiEndpoint: "http://localhost:11434"

    available: false
    supportsImages: _modelCapabilities[currentModel]?.includes("vision") ?? false

    property var _modelCapabilities: ({})

    function _fetchModelCapabilities(modelName): void {
        if (!modelName)
            return;

        if (_modelCapabilities[modelName] !== undefined)
            return;

        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let capabilities = response.capabilities || [];

                        let newCapabilities = Object.assign({}, _modelCapabilities);
                        newCapabilities[modelName] = capabilities;
                        _modelCapabilities = newCapabilities;
                    } catch (e) {
                        console.error("Ollama: Failed to parse model details:", e);
                    }
                }
            }
        };

        xhr.open("POST", `${root.apiEndpoint}/api/show`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({
            model: modelName
        }));
    }

    onCurrentModelChanged: {
        _fetchModelCapabilities(currentModel);
    }

    settings: ColumnLayout {
        spacing: 4

        SettingsCard {
            title: "API Endpoint"
            summary: "URL of the Ollama server"

            controls: StyledTextInput {
                text: root.apiEndpoint
                width: 250
                placeholderText: "http://localhost:11434"

                onAccepted: ChatConnector.setProviderEndpoint(root.providerId, text)
            }

            Layout.fillWidth: true
            Layout.preferredHeight: 36
        }
    }

    // Track current XMLHttpRequest for chat (to support cancellation)
    property var _chatRequest: null
    property int _lastProcessedIndex: 0

    function _processStreamingResponse(): void {
        if (!_chatRequest)
            return;

        let responseText = _chatRequest.responseText;
        if (responseText.length <= _lastProcessedIndex)
            return;

        // Get new data since last processed
        let newData = responseText.substring(_lastProcessedIndex);
        let lines = newData.split("\n");

        // Process complete lines (keep last incomplete line for next iteration)
        for (let i = 0; i < lines.length - 1; i++) {
            let line = lines[i].trim();
            if (line === "")
                continue;

            try {
                let response = JSON.parse(line);

                if (response.message && response.message.content) {
                    let chunk = response.message.content;
                    root.currentResponse += chunk;
                    root.responseChunk(chunk);
                }

                if (response.done === true) {
                    root.busy = false;
                    root.responseComplete(root.currentResponse);
                    root._chatRequest = null;
                    return;
                }

                if (response.error) {
                    root.busy = false;
                    root.errorMessage = response.error;
                    root.responseError(response.error);
                    root._chatRequest = null;
                    return;
                }
            } catch (e) {
                // Ignore parse errors for partial data
            }
        }

        // Update last processed index (keep incomplete last line)
        let lastNewlineIndex = newData.lastIndexOf("\n");
        if (lastNewlineIndex >= 0) {
            _lastProcessedIndex += lastNewlineIndex + 1;
        }
    }

    function fetchModels(): void {
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let modelNames = [];

                        if (response.models && Array.isArray(response.models)) {
                            for (let model of response.models) {
                                if (model.name) {
                                    modelNames.push(model.name);
                                }
                            }
                        }

                        root.models = modelNames;
                        root.available = modelNames.length > 0;

                        if (modelNames.length > 0 && root.currentModel === "") {
                            root.currentModel = modelNames[0];
                        }

                        // Fetch capabilities for all models
                        for (let modelName of modelNames) {
                            root._fetchModelCapabilities(modelName);
                        }

                        root.modelsLoaded(modelNames);
                        root.errorMessage = "";
                    } catch (e) {
                        console.error("Ollama: Failed to parse models response:", e);
                        root.errorMessage = "Failed to parse models response";
                        root.available = false;
                    }
                } else {
                    root.available = false;
                    root.errorMessage = "Failed to connect to Ollama";
                }
            }
        };

        xhr.open("GET", `${root.apiEndpoint}/api/tags`);
        xhr.send();
    }

    function sendMessage(message, history, images = null) {
        if (root.busy) {
            console.warn("Ollama: Already processing a request");
            return;
        }

        if (root.currentModel === "") {
            root.errorMessage = "No model selected";
            root.responseError(root.errorMessage);
            return;
        }

        root.busy = true;
        root.currentResponse = "";
        root.errorMessage = "";
        root._lastProcessedIndex = 0;

        // Build messages array
        let messages = [];

        if (history && Array.isArray(history)) {
            for (let msg of history) {
                let historyMsg = {
                    role: msg.role,
                    content: msg.content
                };
                // Include images from history if present (extract base64 from image objects)
                if (msg.images && Array.isArray(msg.images) && msg.images.length > 0) {
                    historyMsg.images = msg.images.map(img => img.base64);
                }
                messages.push(historyMsg);
            }
        }

        // Build current message with optional images
        let currentMsg = {
            role: "user",
            content: message
        };

        // Add images if provided (Ollama expects base64 strings in images array)
        if (images && Array.isArray(images) && images.length > 0) {
            currentMsg.images = images.map(img => img.base64);
        }

        messages.push(currentMsg);

        let payload = {
            model: root.currentModel,
            messages: messages,
            stream: true
        };

        let xhr = new XMLHttpRequest();
        root._chatRequest = xhr;

        xhr.onreadystatechange = function () {
            // Process streaming data as it arrives
            if (xhr.readyState === XMLHttpRequest.LOADING) {
                root._processStreamingResponse();
            }

            if (xhr.readyState === XMLHttpRequest.DONE) {
                // Process any remaining data
                root._processStreamingResponse();

                if (xhr.status !== 200 && root.busy) {
                    root.busy = false;
                    root.errorMessage = "Chat request failed";
                    root.responseError(root.errorMessage);
                } else if (root.busy && root.currentResponse !== "") {
                    // Request completed but done signal wasn't received
                    root.busy = false;
                    root.responseComplete(root.currentResponse);
                }

                root._chatRequest = null;
            }
        };

        xhr.open("POST", `${root.apiEndpoint}/api/chat`);
        xhr.setRequestHeader("Content-Type", "application/json");
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
        let prompt = `Summarize the following conversation in 5 words or fewer. Reply with only the title, no quotes, no punctuation.\n\nUser: ${userMessage}\nAssistant: ${assistantResponse}`;

        let payload = {
            model: root.currentModel,
            messages: [
                {
                    role: "user",
                    content: prompt
                }
            ],
            stream: false
        };

        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let response = JSON.parse(xhr.responseText);
                        let title = (response.message?.content ?? "").trim();
                        if (title !== "")
                            callback(title);
                    } catch (e) {
                        console.warn("Ollama: Failed to parse title response:", e);
                    }
                }
            }
        };

        xhr.open("POST", `${root.apiEndpoint}/api/chat`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(payload));
    }

    function checkAvailability(): void {
        fetchModels();
    }
}
