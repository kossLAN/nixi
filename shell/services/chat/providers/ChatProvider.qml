import QtQuick
import Quickshell

Scope {
    id: root

    property bool enabled: false
    property string name: ""
    property string icon: ""
    property string providerId: "default"

    property string apiEndpoint: ""
    property string currentModel: ""
    property list<string> models: []

    property bool available: false
    property bool busy: false
    property string errorMessage: ""

    property string currentResponse: ""

    // Whether this provider supports image uploads (vision capability)
    property bool supportsImages: false

    // Whether this provider supports toggling web/internet search
    property bool supportsInternetSearch: false

    // Whether internet search is currently enabled (only relevant if supportsInternetSearch is true)
    property bool internetSearchEnabled: true

    // Whether this provider manages conversation history remotely (not in local SQLite)
    property bool remoteHistory: false

    // Settings component for this provider (to be overridden)
    property Component settings: null

    signal responseChunk(string chunk)
    signal responseComplete(string fullResponse)
    signal responseError(string error)
    signal modelsLoaded(list<string> models)

    // Remote history signals (only used when remoteHistory is true)
    signal conversationsLoaded(var conversations)  // [{id, title, updatedAt}]
    signal conversationLoaded(var messages)         // [{role, content, timestamp}]

    // Abstract functions to be implemented by providers
    // Fetches available models from the provider
    function fetchModels(): void {
        console.error(`${name}: fetchModels() not implemented`);
    }

    // Sends a message with conversation history, streams response
    // history: array of {role: "user"|"assistant", content: string, images?: [{base64: string, mediaType: string}]}
    // images: optional array of image objects {base64: string, mediaType: string} for the current message
    function sendMessage(message, history, images = null) {
        console.error(`${name}: sendMessage() not implemented`);
    }

    // Generates a short title from the first user message + assistant response.
    // Calls callback(title: string) when done. Default: no-op (providers override).
    function generateTitle(userMessage, assistantResponse, callback) {
        // Base implementation: fall back to a local truncation
        let title = userMessage.substring(0, 50).trim();
        if (userMessage.length > 50)
            title += "...";
        callback(title);
    }

    // Cancels the current request
    function cancelRequest(): void {
        console.error(`${name}: cancelRequest() not implemented`);
    }

    // Checks if the provider is available/configured
    function checkAvailability(): void {
        console.error(`${name}: checkAvailability() not implemented`);
    }

    // Remote history functions (override when remoteHistory is true)
    function loadRemoteConversations() {
        console.error(`${name}: loadRemoteConversations() not implemented`);
    }

    function loadRemoteConversation(conversationId) {
        console.error(`${name}: loadRemoteConversation() not implemented`);
    }

    function deleteRemoteConversation(conversationId, callback) {
        console.error(`${name}: deleteRemoteConversation() not implemented`);
    }

    function resetThread() {
    // Base: no-op. Remote providers override to clear thread state.
    }
}
