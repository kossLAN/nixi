pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

import qs
import qs.services.chat.providers

Singleton {
    id: root

    // Configuration
    readonly property string configPath: `${ShellSettings.folderPath}/chat.json`
    property alias chatAdapter: chatAdapter

    // All registered providers
    property list<ChatProvider> providers: [
        OllamaProvider {},
        AnthropicProvider {},
    ]

    // Current active provider
    property alias currentProviderId: chatAdapter.currentProviderId
    property var currentProvider: providers.find(x => x.providerId === currentProviderId && x.enabled)
    property string currentModel: currentProvider?.currentModel ?? ""

    // State
    property bool busy: currentProvider ? currentProvider.busy : false
    property string errorMessage: currentProvider ? currentProvider.errorMessage : ""

    // Internet search toggle (provider-level feature)
    property bool supportsInternetSearch: currentProvider?.supportsInternetSearch ?? false
    property bool internetSearchEnabled: currentProvider?.internetSearchEnabled ?? true

    function toggleInternetSearch(): void {
        if (currentProvider?.supportsInternetSearch)
            currentProvider.internetSearchEnabled = !currentProvider.internetSearchEnabled;
    }

    // Current streaming response
    property string currentResponse: ""

    // Conversation history: [{id: int, role: "user"|"assistant", content: string, timestamp: date}]
    property var history: []

    // Current conversation (int for local providers, string UUID for remote)
    property var currentConversationId: null
    property var conversations: []  // [{id, title, created_at, updated_at}]

    signal responseChunk(string chunk)
    signal responseComplete(string fullResponse)
    signal responseError(string error)
    signal providerChanged(var provider)
    signal modelsUpdated(list<string> models)
    signal historyUpdated

    FileView {
        id: chatFile
        path: root.configPath
        watchChanges: true
        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        onLoaded: root._restoreProviderState()

        JsonAdapter {
            id: chatAdapter

            property string currentProviderId: "ollama"
            property var providerState: ({})
        }
    }

    function _getDatabase() {
        return LocalStorage.openDatabaseSync("NixiChat", "1.0", "Nixi Chat History", 1000000);
    }

    function _initDatabase(): void {
        let db = _getDatabase();
        db.transaction(function (tx) {
            tx.executeSql(`
                CREATE TABLE IF NOT EXISTS conversations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT,
                    provider_id TEXT,
                    model TEXT,
                    created_at TEXT,
                    updated_at TEXT
                )
            `);

            tx.executeSql(`
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    conversation_id INTEGER,
                    role TEXT,
                    content TEXT,
                    timestamp TEXT,
                    images TEXT,
                    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
                )
            `);

            // Migration: Add images column if it doesn't exist
            try {
                tx.executeSql("ALTER TABLE messages ADD COLUMN images TEXT");
            } catch (e) {
                // Column already exists, ignore
            }
        });
    }

    function createConversation(title): int {
        let db = _getDatabase();
        let newId = -1;
        let now = new Date().toISOString();
        let convTitle = title || "New conversation";

        db.transaction(function (tx) {
            tx.executeSql("INSERT INTO conversations (title, provider_id, model, created_at, updated_at) VALUES (?, ?, ?, ?, ?)", [convTitle, currentProviderId, currentModel, now, now]);
            let result = tx.executeSql("SELECT last_insert_rowid() as id");
            newId = result.rows.item(0).id;
        });

        currentConversationId = newId;
        loadConversations();
        return newId;
    }

    function _saveMessage(conversationId: int, role: string, content: string, timestamp: date, images = null): int {
        let db = _getDatabase();
        let messageId = -1;

        // Serialize images as JSON string if present
        let imagesJson = null;
        if (images && Array.isArray(images) && images.length > 0) {
            imagesJson = JSON.stringify(images);
        }

        db.transaction(function (tx) {
            tx.executeSql("INSERT INTO messages (conversation_id, role, content, timestamp, images) VALUES (?, ?, ?, ?, ?)", [conversationId, role, content, timestamp.toISOString(), imagesJson]);
            let result = tx.executeSql("SELECT last_insert_rowid() as id");
            messageId = result.rows.item(0).id;

            // Update conversation's updated_at
            tx.executeSql("UPDATE conversations SET updated_at = ? WHERE id = ?", [timestamp.toISOString(), conversationId]);
        });

        return messageId;
    }

    function loadConversations(): void {
        // Remote history providers manage their own conversations
        if (currentProvider?.remoteHistory) {
            currentProvider.loadRemoteConversations();
            return;
        }

        let db = _getDatabase();
        let convs = [];

        db.readTransaction(function (tx) {
            let result = tx.executeSql("SELECT id, title, provider_id, model, created_at, updated_at FROM conversations ORDER BY updated_at DESC");
            for (let i = 0; i < result.rows.length; i++) {
                let row = result.rows.item(i);
                convs.push({
                    id: row.id,
                    title: row.title,
                    providerId: row.provider_id,
                    model: row.model,
                    createdAt: new Date(row.created_at),
                    updatedAt: new Date(row.updated_at)
                });
            }
        });

        conversations = convs;
    }

    function loadConversation(conversationId): void {
        // Remote history providers load from server
        if (currentProvider?.remoteHistory) {
            currentConversationId = conversationId;
            history = [];
            historyUpdated();
            currentProvider.loadRemoteConversation(conversationId);
            return;
        }

        let db = _getDatabase();
        let msgs = [];

        db.readTransaction(function (tx) {
            let result = tx.executeSql("SELECT id, role, content, timestamp, images FROM messages WHERE conversation_id = ? ORDER BY id ASC", [conversationId]);
            for (let i = 0; i < result.rows.length; i++) {
                let row = result.rows.item(i);
                let msg = {
                    id: row.id,
                    role: row.role,
                    content: row.content,
                    timestamp: new Date(row.timestamp)
                };

                // Parse images from JSON if present
                if (row.images) {
                    try {
                        msg.images = JSON.parse(row.images);
                    } catch (e) {
                        // Ignore parse errors
                    }
                }

                msgs.push(msg);
            }
        });

        currentConversationId = conversationId;
        history = msgs;
        historyUpdated();
    }

    function deleteConversation(conversationId): void {
        // Remote history providers delete on server
        if (currentProvider?.remoteHistory) {
            currentProvider.deleteRemoteConversation(conversationId, function(success) {
                if (success) {
                    if (root.currentConversationId === conversationId) {
                        root.currentConversationId = null;
                        root.history = [];
                        root.historyUpdated();
                    }
                    root.loadConversations();
                }
            });
            return;
        }

        let db = _getDatabase();

        db.transaction(function (tx) {
            tx.executeSql("DELETE FROM messages WHERE conversation_id = ?", [conversationId]);
            tx.executeSql("DELETE FROM conversations WHERE id = ?", [conversationId]);
        });

        if (currentConversationId === conversationId) {
            currentConversationId = null;
            history = [];
            historyUpdated();
        }

        loadConversations();
    }

    function updateConversationTitle(conversationId, title: string): void {
        let db = _getDatabase();

        db.transaction(function (tx) {
            tx.executeSql("UPDATE conversations SET title = ? WHERE id = ?", [title, conversationId]);
        });

        loadConversations();
    }

    function _autoGenerateTitle(content: string): string {
        return "New conversation";
    }

    function _restoreProviderState(): void {
        for (let provider of providers) {
            const state = chatAdapter.providerState[provider.providerId];

            if (state?.endpoint)
                provider.apiEndpoint = state.endpoint;

            if (state?.enabled !== undefined)
                provider.enabled = state.enabled;

            if (state?.apiKey)
                provider.apiKey = state.apiKey;
        }

        refreshAllModels();
        loadConversations();
    }

    function getProviderModel(providerId: string): string {
        const state = chatAdapter.providerState[providerId];
        return state?.model ?? "";
    }

    function setProviderModel(providerId: string, model: string): void {
        let newState = Object.assign({}, chatAdapter.providerState);

        if (!newState[providerId])
            newState[providerId] = {};

        newState[providerId].model = model;
        chatAdapter.providerState = newState;
    }

    function getProviderEndpoint(providerId: string): string {
        const state = chatAdapter.providerState[providerId];
        const provider = providers.find(p => p.providerId === providerId);
        return state?.endpoint ?? provider?.apiEndpoint ?? "";
    }

    function setProviderEndpoint(providerId: string, endpoint: string): void {
        let newState = Object.assign({}, chatAdapter.providerState);

        if (!newState[providerId])
            newState[providerId] = {};

        newState[providerId].endpoint = endpoint;
        chatAdapter.providerState = newState;

        const provider = providers.find(p => p.providerId === providerId);

        if (provider) {
            provider.apiEndpoint = endpoint;
            provider.checkAvailability();
        }
    }

    function isProviderEnabled(providerId: string): bool {
        const state = chatAdapter.providerState[providerId];
        const provider = providers.find(p => p.providerId === providerId);

        return state?.enabled ?? provider?.enabled ?? true;
    }

    function setProviderEnabled(providerId: string, enabled: bool): void {
        let newState = Object.assign({}, chatAdapter.providerState);

        if (!newState[providerId])
            newState[providerId] = {};

        newState[providerId].enabled = enabled;
        chatAdapter.providerState = newState;

        const provider = providers.find(p => p.providerId === providerId);

        if (provider) {
            provider.enabled = enabled;
        }
    }

    function getProviderApiKey(providerId: string): string {
        const state = chatAdapter.providerState[providerId];

        return state?.apiKey ?? "";
    }

    function setProviderApiKey(providerId: string, apiKey: string): void {
        let newState = Object.assign({}, chatAdapter.providerState);

        if (!newState[providerId])
            newState[providerId] = {};

        newState[providerId].apiKey = apiKey;
        chatAdapter.providerState = newState;
    }

    Connections {
        target: root.currentProvider != undefined ? root.currentProvider : null

        function onResponseChunk(chunk) {
            root.currentResponse = root.currentProvider.currentResponse;
            root.responseChunk(chunk);
        }

        function onResponseComplete(fullResponse) {
            // Capture state before addToHistory mutates history
            const isFirstExchange = root.history.length === 1;
            const firstUserMessage = isFirstExchange ? root.history[0].content : "";
            const convId = root.currentConversationId;
            const isRemote = root.currentProvider?.remoteHistory ?? false;

            root.addToHistory("assistant", fullResponse);
            root.currentResponse = "";
            root.responseComplete(fullResponse);

            // Remote history providers: refresh the conversation list (server generates titles)
            if (isRemote) {
                root.loadConversations();
                return;
            }

            // After the first exchange, ask the AI for a real title
            if (isFirstExchange && convId && root.currentProvider) {
                root.currentProvider.generateTitle(firstUserMessage, fullResponse, function(title) {
                    root.updateConversationTitle(convId, title);
                });
            }
        }

        function onResponseError(error) {
            root.currentResponse = "";
            root.responseError(error);
        }

        function onModelsLoaded(models) {
            const savedModel = root.getProviderModel(root.currentProvider.providerId);

            if (savedModel && models.includes(savedModel)) {
                root.currentProvider.currentModel = savedModel;
                root.currentModel = savedModel;
            }

            root.modelsUpdated(models);
        }
    }

    // Handle remote history signals from provider
    Connections {
        target: root.currentProvider?.remoteHistory ? root.currentProvider : null

        function onConversationsLoaded(conversations) {
            root.conversations = conversations;
        }

        function onConversationLoaded(messages) {
            root.history = messages;
            root.historyUpdated();
        }
    }

    function setModel(model: string): void {
        currentModel = model;

        if (currentProvider) {
            currentProvider.currentModel = model;
            setProviderModel(currentProvider.providerId, model);
        }
    }

    function setProviderAndModel(providerId: string, model: string): void {
        if (currentProviderId !== providerId) {
            currentProviderId = providerId;

            // Reset conversation state on provider switch
            currentConversationId = null;
            history = [];
            currentResponse = "";

            if (currentProvider?.remoteHistory) {
                currentProvider.resetThread();
            }

            historyUpdated();
            providerChanged(currentProvider);
            loadConversations();
        }

        setModel(model);
    }

    function sendMessage(message, images = null) {
        if (!currentProvider) {
            errorMessage = "No provider selected";
            responseError(errorMessage);
            return;
        }

        if (!currentProvider.enabled) {
            errorMessage = "Provider is disabled";
            responseError(errorMessage);
            return;
        }

        if (!currentProvider.available) {
            errorMessage = "Provider not available";
            responseError(errorMessage);
            return;
        }

        currentResponse = "";

        addToHistory("user", message, images);

        // Remote history providers manage context server-side; pass empty history
        if (currentProvider.remoteHistory) {
            currentProvider.sendMessage(message, [], images);
            return;
        }

        let providerHistory = [];

        const contextHistory = history.slice(Math.max(0, history.length - ShellSettings.settings.chatContextMessages));
        for (let msg of contextHistory) {
            if (msg !== history[history.length - 1]) {
                let historyEntry = {
                    role: msg.role,
                    content: msg.content
                };

                if (msg.images && msg.images.length > 0) {
                    historyEntry.images = msg.images;
                }

                providerHistory.push(historyEntry);
            }
        }

        currentProvider.sendMessage(message, providerHistory, images);
    }

    function cancelRequest(): void {
        if (currentProvider) {
            currentProvider.cancelRequest();
        }
    }

    function refreshModels(): void {
        if (currentProvider) {
            currentProvider.fetchModels();
        }
    }

    function refreshAllModels(): void {
        for (let provider of providers) {
            provider.fetchModels();
        }
    }

    function addToHistory(role: string, content: string, images = null, references = null): void {
        let timestamp = new Date();

        // Remote history providers don't use local SQLite
        if (currentProvider?.remoteHistory) {
            let newHistory = history.slice();
            let historyEntry = {
                role: role,
                content: content,
                timestamp: timestamp
            };

            if (images && Array.isArray(images) && images.length > 0) {
                historyEntry.images = images;
            }

            if (references && Array.isArray(references) && references.length > 0) {
                historyEntry.references = references;
            }

            newHistory.push(historyEntry);
            history = newHistory;
            historyUpdated();
            return;
        }

        // Create a new conversation if needed
        if (!currentConversationId) {
            let title = role === "user" ? _autoGenerateTitle(content) : "New conversation";
            createConversation(title);
        }

        let messageId = _saveMessage(currentConversationId, role, content, timestamp, images);

        let newHistory = history.slice();
        let historyEntry = {
            id: messageId,
            role: role,
            content: content,
            timestamp: timestamp
        };

        // Add images if present
        if (images && Array.isArray(images) && images.length > 0) {
            historyEntry.images = images;
        }

        newHistory.push(historyEntry);

        history = newHistory;

        historyUpdated();
        loadConversations();
    }

    function newConversation(): void {
        currentConversationId = null;
        history = [];
        currentResponse = "";

        if (currentProvider?.remoteHistory) {
            currentProvider.resetThread();
        }

        historyUpdated();
    }

    function clearHistory(): void {
        if (currentConversationId)
            deleteConversation(currentConversationId);

        currentConversationId = null;
        history = [];
        currentResponse = "";

        historyUpdated();
    }

    function getModels(): list<string> {
        if (currentProvider) {
            return currentProvider.models;
        }

        return [];
    }

    function isAvailable(): bool {
        return providers.filter(x => x.enabled && x.available).length != 0;
    }

    Component.onCompleted: {
        _initDatabase();
        loadConversations();
    }
}
