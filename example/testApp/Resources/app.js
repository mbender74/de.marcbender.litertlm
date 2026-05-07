/**
 * TitaniumLiteRTLM – Vollständiges ChatDemo-Beispiel
 *
 * Dieses Beispiel demonstriert alle Funktionen des de.marcbender.litertlm-Moduls:
 * - Modell-Download und -Verwaltung
 * - Engine-Initialisierung (CPU/GPU)
 * - Text-Generierung
 * - Streaming-Ausgabe
 * - Conversation mit History
 * - Tool Calling (Wetter, Rechner, Würfel)
 * - Mehrmodale Eingabe (Kamera, Fotomediathek)
 * - Voice/Audio-Eingabe
 * - Fehlerbehandlung
 *
 * Inspiriert vom Swift ChatDemo:
 * /Users/marcbender/LiteRTLM-Swift-SDK/Examples/ChatDemo
 */

// ============================================================
// Module einbinden
// ============================================================
var litertlm = require('de.marcbender.litertlm');

// ============================================================
// Globale Status- und Service-Variablen
// ============================================================
var hasLoadedModel = false;
var isGenerating = false;
var isModelLoading = false;
var selectedBackend = 'cpu'; // 'cpu' oder 'gpu'
var toolsEnabled = false;
var pendingImage = null;
var pendingAudio = null;
var isRecording = false;

// Conversation- und Engine-Referenzen (wird von Titanium gesetzt)
var engine = null;
var conversation = null;
var downloader = null;

// Download-Fortschritt
var downloadProgress = 0;
var downloadedBytes = 0;
var totalBytes = 0;
var downloadSpeed = 0;

// Modell-Info (Gemma 4 E2B von HuggingFace)
var modelInfo = {
    name: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    expectedSize: 2583085056, // ~2.4 GB
    fileName: 'gemma-4-E2B-it.litertlm'
};

// System-Prompt
var systemPrompt = 'You are a helpful, friendly AI assistant running entirely on-device via LiteRTLM Swift SDK and Google\'s Gemma 4. You are part of a demo app that showcases on-device LLM inference. Be concise, helpful, and conversational. You can see images the user sends. Keep responses short unless asked for detail.';

// ============================================================
// UI-Komponenten erstellen
// ============================================================

// Hauptfenster
var mainWin = Ti.UI.createWindow({
    backgroundColor: '#1a1a2e',
    layout: 'vertical'
});

// Header-Bereich
var headerView = Ti.UI.createView({
    layout: 'horizontal',
    height: 44,
    backgroundColor: '#16213e',
    top: 0,
    left: 0,
    right: 0
});

var headerTitle = Ti.UI.createLabel({
    text: 'LiteRTLM Chat',
    color: '#e94560',
    font: { fontSize: 18, fontWeight: 'bold' },
    left: 10,
    width: 200
});

var statusLabel = Ti.UI.createLabel({
    text: 'Bereit – Tippe "Modell laden"',
    color: '#a0a0a0',
    font: { fontSize: 12 },
    left: 10,
    width: 220
});

// Header-Buttons (Rechts)
var toolsButton = Ti.UI.createButton({
    title: 'Tools',
    font: { fontSize: 14, fontWeight: 'bold' },
    color: '#a0a0a0',
    right: 60,
    width: 60,
    height: 30
});

var resetButton = Ti.UI.createButton({
    title: '↺',
    font: { fontSize: 16 },
    color: '#a0a0a0',
    right: 10,
    width: 40,
    height: 30
});

headerView.add(headerTitle);
headerView.add(statusLabel);
headerView.add(toolsButton);
headerView.add(resetButton);

// ============================================================
// Chat-Nachrichten-Liste (TableView)
// ============================================================
var messages = []; // { role: 'user'|'model'|'system', text: '', image: null }

var chatTableView = Ti.UI.createTableView({
    backgroundColor: '#0f3460',
    layout: 'vertical',
    top: 0,
    bottom: 180,
    left: 0,
    right: 0,
    separatorColor: 'transparent',
    hasUnread: false
});

function addMessage(role, text, imageData) {
    var msg = {
        id: Ti.Utils.createUUID ? Ti.Utils.createUUID() : (new Date()).getTime() + Math.random(),
        role: role,
        text: text || '',
        image: imageData || null,
        timestamp: new Date()
    };
    messages.push(msg);
    renderAllMessages();
}

function updateMessage(index, text) {
    if (index >= 0 && index < messages.length) {
        messages[index].text = text;
        renderAllMessages();
    }
}

function clearMessages() {
    messages = [];
    renderAllMessages();
}

function renderAllMessages() {
    var rows = [];

    for (var i = 0; i < messages.length; i++) {
        var msg = messages[i];
        var row = createMessageRow(msg, i);
        rows.push(row);
    }

    chatTableView.setData(rows);

    // Zum letzten Eintrag scrollen
    if (messages.length > 0) {
        chatTableView.scrollToIndex(messages.length - 1);
    }
}

function createMessageRow(msg, index) {
    var row = Ti.UI.createTableViewRow({
        height: 44,
        selectionStyle: Ti.UI.iOS.TableViewRow.TABLEVIEW_ROW_STYLE_PLAIN,
        backgroundColor: 'transparent',
        hasUnread: false
    });

    var container = Ti.UI.createView({
        layout: 'horizontal',
        height: 44,
        top: 5,
        bottom: 5
    });

    if (msg.role === 'system') {
        // System-Nachricht (zentriert, kleiner Text)
        var systemLabel = Ti.UI.createLabel({
            text: msg.text,
            color: '#a0a0a0',
            font: { fontSize: 11, fontStyle: 'italic' },
            textAlign: 'center',
            width: '100%',
            height: 44,
            top: 5,
            bottom: 5
        });
        row.add(systemLabel);
        return row;
    }

    // Nutzer-Nachricht rechts, Modell-Nachricht links
    var isUser = msg.role === 'user';

    var bubble = Ti.UI.createView({
        layout: 'vertical',
        height: 44,
        width: '80%',
        backgroundColor: isUser ? '#e94560' : '#16213e',
        borderRadius: 12,
        padding: 10,
        right: isUser ? 5 : Ti.UI.RELATIVE_TO_PARENT,
        left: isUser ? Ti.UI.RELATIVE_TO_PARENT : 5
    });

    // Bild anzeigen, wenn vorhanden
    if (msg.image) {
        var imageView = Ti.UI.createImageView({
            image: msg.image,
            height: 150,
            width: 150,
            borderRadius: 8,
            top: 5,
            left: 5,
            right: 5
        });
        bubble.add(imageView);
    }

    // Text anzeigen
    var textLabel = Ti.UI.createLabel({
        text: msg.text || (isUser ? '[Foto]' : '[Generiere...]'),
        color: isUser ? '#ffffff' : '#e0e0e0',
        font: { fontSize: 14, fontWeight: 'normal' },
        textAlign: 'left',
        height: 44,
        width: '100%',
        top: msg.image ? 5 : 0,
        bottom: 5,
        wordWrap: true,
        selectionColor: '#a0a0a0'
    });
    bubble.add(textLabel);

    container.add(bubble);
    row.add(container);
    return row;
}

// ============================================================
// Download-Fortschritt-Bereich
// ============================================================
var downloadView = Ti.UI.createView({
    layout: 'vertical',
    height: 44,
    top: 10,
    bottom: 10,
    left: 0,
    right: 0,
});

var progressLabel = Ti.UI.createLabel({
    text: '',
    color: '#a0a0a0',
    font: { fontSize: 11 },
    height: 20,
    textAlign: 'center',
    top: 2
});

var progressBar = Ti.UI.createProgressBar({
    width: 260,
    height: 20,
    bottom: 2,
    value: 0
});

downloadView.add(progressLabel);
downloadView.add(progressBar);

// ============================================================
// Modell-Ladebereich
// ============================================================
var loadModelView = Ti.UI.createView({
    layout: 'vertical',
    height: 44,
    top: 10,
    bottom: 10,
    left: 0,
    right: 0,
});

// Backend-Auswahl
var backendPicker = Ti.UI.createView({
    layout: 'horizontal',
    bottom: 30,
    height: 40,
    width: 220
});

var cpuButton = Ti.UI.createButton({
    title: 'CPU',
    font: { fontSize: 14, fontWeight: 'bold' },
    width: 100,
    height: 36,
    backgroundColor: '#e94560',
    color: '#ffffff',
    borderRadius: 6
});

var gpuButton = Ti.UI.createButton({
    title: 'GPU',
    font: { fontSize: 14, fontWeight: 'bold' },
    width: 100,
    height: 36,
    backgroundColor: '#2a2a4a',
    color: '#a0a0a0',
    borderRadius: 6,
    right: 20
});

backendPicker.add(cpuButton);
backendPicker.add(gpuButton);

var backendLabel = Ti.UI.createLabel({
    text: 'Backend auswählen:',
    color: '#e0e0e0',
    font: { fontSize: 13, fontWeight: 'bold' },
    top: 5,
    left: 10
});

var backendInfo = Ti.UI.createLabel({
    text: 'CPU: Kompatibel mit allen Geräten\nGPU: Schnellere Inferenz via Metal',
    color: '#a0a0a0',
    font: { fontSize: 10 },
    top: 5,
    left: 10,
    right: 10,
    height: 30
});

var loadModelButton = Ti.UI.createButton({
    title: 'Modell laden',
    font: { fontSize: 16, fontWeight: 'bold' },
    color: '#ffffff',
    backgroundColor: '#e94560',
    borderRadius: 8,
    height: 44,
    width: 200,
    top: 20
});

loadModelView.add(backendLabel);
loadModelView.add(backendPicker);
loadModelView.add(backendInfo);
loadModelView.add(loadModelButton);

// ============================================================
// Eingabebereich
// ============================================================
var inputBar = Ti.UI.createView({
    layout: 'horizontal',
    height: 50,
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#16213e',
    padding: 5
});

var inputTextField = Ti.UI.createTextField({
    hint: 'Nachricht eingeben...',
    color: '#ffffff',
    backgroundColor: '#0f3460',
    borderColor: '#2a2a4a',
    borderWidth: 1,
    borderRadius: 20,
    height: 36,
    width: '80%',
    left: 5,
    returnKeyType: Ti.UI.RETURNKEY_DEFAULT,
    keyboardToolbar: null
});

// Plus-Button: zeigt ein OptionDialog (compatibel mit Titanium 13.x)
var plusButton = Ti.UI.createButton({
    title: '+',
    font: { fontSize: 20, fontWeight: 'bold' },
    color: '#e0e0e0',
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#2a2a4a'
});

// Plus-Button zeigt Optionen (Foto, Audio)
plusButton.addEventListener("click", function() {
    var options = ["Foto aufnehmen", "Fotomediathek", "Stimme aufnehmen", "Abbrechen"];
    var dialog = Ti.UI.createOptionDialog({
        title: "Eingabe",
        options: options,
        cancel: 3,
        destructive: 3
    });
    dialog.addEventListener("click", function(e) {
        if (e.index === 0) { openCamera(); }
        else if (e.index === 1) { openPhotoLibrary(); }
        else if (e.index === 2) { toggleVoiceRecording(); }
    });
    dialog.show();
});
var sendButton = Ti.UI.createButton({
    systemButton: Ti.UI.iOS.SystemButton.PLAY
});

var stopButton = Ti.UI.createButton({
    systemButton: Ti.UI.iOS.SystemButton.STOP,
    color: '#ff0000'
});

function updateInputButtons() {
    if (isGenerating) {
        inputBar.remove(sendButton);
        inputBar.add(stopButton);
    } else {
        inputBar.remove(stopButton);
        inputBar.add(sendButton);
    }
}

inputBar.add(plusButton);
inputBar.add(inputTextField);
inputBar.add(sendButton);
inputBar.add(stopButton);
inputBar.remove(stopButton);

// ============================================================
// Event-Listener für Buttons
// ============================================================

// Backend-Auswahl
cpuButton.addEventListener('click', function() {
    selectedBackend = 'cpu';
    cpuButton.backgroundColor = '#e94560';
    cpuButton.color = '#ffffff';
    gpuButton.backgroundColor = '#2a2a4a';
    gpuButton.color = '#a0a0a0';
    backendInfo.text = 'Kompatibel mit allen Geräten';
});

gpuButton.addEventListener('click', function() {
    selectedBackend = 'gpu';
    gpuButton.backgroundColor = '#e94560';
    gpuButton.color = '#ffffff';
    cpuButton.backgroundColor = '#2a2a4a';
    cpuButton.color = '#a0a0a0';
    backendInfo.text = 'Schnellere Inferenz via Metal';
});

// Modell laden
loadModelButton.addEventListener('click', function() {
    if (isModelLoading) return;
    loadModel();
});

// Sende-Button
sendButton.addEventListener('click', function() {
    if (isGenerating) return;
    sendMessage();
});

// Stop-Button
stopButton.addEventListener('click', function() {
    stopGeneration();
});

// Werkzeug-Button
toolsButton.addEventListener('click', function() {
    showToolsSheet();
});

// Zurück-Button
resetButton.addEventListener('click', function() {
    cleanup();
});

// ============================================================
// Hauptfunktionen
// ============================================================

/**
 * Modell laden (Download + Engine-Initialisierung)
 */
function loadModel() {
    if (isModelLoading || hasLoadedModel) return;

    isModelLoading = true;
    loadModelButton.setTitle('Laden...');
    loadModelButton.enabled = false;
    statusLabel.text = 'Modell wird geladen...';

    // Schritt 1: Downloader erstellen
    var modelsDir = Ti.Filesystem.applicationStorageDirectory + 'models/';
    var fs = Ti.Filesystem.getFile(modelsDir);
    if (!fs.exists()) {
        fs.createDirectory();
    }

    downloader = litertlm.createDownloader({
        modelsDirectory: modelsDir
    });

    // Download-Fortschritt
    downloader.addEventListener('downloadprogress', function(e) {
        downloadProgress = e.progress || 0;
        downloadedBytes = e.bytesDownloaded || 0;
        totalBytes = e.totalBytes || modelInfo.expectedSize;

        // Geschwindigkeit berechnen
        var now = new Date().getTime();
        if (lastDownloadTime > 0) {
            var elapsed = (now - lastDownloadTime) / 1000;
            if (elapsed > 0 && lastDownloadedBytes > 0) {
                var bytesInInterval = downloadedBytes - lastDownloadedBytes;
                var instantSpeed = bytesInInterval / elapsed;
                downloadSpeed = downloadSpeed === 0 ? instantSpeed : downloadSpeed * 0.7 + instantSpeed * 0.3;
            }
        }
        lastDownloadTime = now;
        lastDownloadedBytes = downloadedBytes;

        // Fortschritt anzeigen
        var percent = Math.round(downloadProgress * 100);
        progressLabel.text = formatBytes(downloadedBytes) + ' / ' + formatBytes(totalBytes) +
            '  •  ' + formatBytes(Math.round(downloadSpeed)) + '/s';
        progressBar.value = downloadProgress;
        statusLabel.text = 'Download: ' + percent + '%';
    });

    downloader.addEventListener('downloadcomplete', function(e) {
        statusLabel.text = 'Download abgeschlossen. Engine wird initialisiert...';
    });

    downloader.addEventListener('downloaderror', function(e) {
        statusLabel.text = 'Download-Fehler: ' + e.message;
        isModelLoading = false;
        loadModelButton.setTitle('Modell laden');
        loadModelButton.enabled = true;
    });

    // Prüfen, ob Modell bereits heruntergeladen
    var exists = downloader.isDownloaded(modelInfo);
    if (!exists) {
        statusLabel.text = 'Modell wird heruntergeladen...';
        downloader.download(modelInfo);
    } else {
        statusLabel.text = 'Modell bereits vorhanden. Engine wird initialisiert...';
        // Direkt zur Engine-Initialisierung
        initializeEngine();
    }
}

var lastDownloadTime = 0;
var lastDownloadedBytes = 0;

/**
 * Engine initialisieren
 */
function initializeEngine() {
    statusLabel.text = 'Engine wird initialisiert (' + selectedBackend.toUpperCase() + ')...';

    var cacheDir = Ti.Filesystem.applicationCachesDirectory + 'litertlm_cache/';
    var cacheFile = Ti.Filesystem.getFile(cacheDir);
    if (!cacheFile.exists()) {
        cacheFile.createDirectory();
    }

    // Engine-Konfiguration
    var config = litertlm.createEngineConfigProxy({
        modelPath: modelInfo.fileName,
        backend: selectedBackend,
        maxTokens: 4096,
        cacheDir: cacheDir,
        logLevel: 'warning'
    });

    litertlm.createEngineWithConfig(config);
}

/**
 * Engine created Event
 */
litertlm.addEventListener('enginecreated', function(e) {
    engine = e.engine;
    statusLabel.text = 'Engine bereit. Conversation wird erstellt...';

    // Conversation erstellen
    var convConfig = litertlm.createConversationConfigProxy({
        systemPrompt: systemPrompt,
        maxOutputTokens: 1024,
        samplerType: 'balanced'
    });

    if (toolsEnabled) {
        // Tools hinzufügen
        var weatherTool = createWeatherTool();
        var calculatorTool = createCalculatorTool();
        var diceTool = createDiceTool();

        convConfig._toolExecutionMode = 'auto';
        convConfig._tools = [weatherTool, calculatorTool, diceTool];
    }

    engine.createConversationWithConfig(convConfig);
});

/**
 * Conversation created Event
 */
litertlm.addEventListener('conversationcreated', function(e) {
    conversation = e.conversation;
    hasLoadedModel = true;
    isModelLoading = false;
    loadModelButton.setTitle('Modell laden');
    loadModelButton.enabled = true;
    statusLabel.text = 'Bereit zum Chat. Sende eine Nachricht!';

    // System-Nachricht hinzufügen
    addMessage('system', 'Bereit zum Chat. Sende eine Nachricht, ein Foto oder benutze die Stimme.');

    // Modell-Ladebereich ausblenden
    mainWin.remove(loadModelView);
    mainWin.remove(downloadView);
});

/**
 * Nachricht senden
 */
function sendMessage() {
    if (!conversation || isGenerating) return;

    var text = inputTextField.value || '';
    var hasMedia = pendingImage !== null || pendingAudio !== null;

    if (!text && !hasMedia) return;

    // Nutzernachricht anzeigen
    var displayText = text;
    if (!text && pendingImage) {
        displayText = '[Foto]';
    } else if (!text && pendingAudio) {
        displayText = '[Sprachnachricht]';
    }

    addMessage('user', displayText, pendingImage);
    inputTextField.value = '';
    pendingImage = null;
    pendingAudio = null;

    // Platzhalter für Modellantwort
    addMessage('model', '');

    // Prompt vorbereiten
    var prompt = text ||
        (pendingImage ? 'Beschreibe, was du auf diesem Bild siehst.' :
         pendingAudio ? 'Reagiere auf diese Sprachnachricht.' : '');

    var hasMediaInput = pendingImage !== null || pendingAudio !== null;

    isGenerating = true;
    updateInputButtons();

    if (hasMediaInput) {
        // Mehrmodale Eingabe
        var contents = [];

        if (text) {
            var textContent = litertlm.createContentProxy({
                type: 'text',
                text: text
            });
            contents.push(textContent);
        }

        if (pendingImage) {
            var imageContent = litertlm.createContentProxy({
                type: 'image',
                imageData: pendingImage,
                maxDimension: 1024
            });
            contents.push(imageContent);
        }

        if (pendingAudio) {
            var audioContent = litertlm.createContentProxy({
                type: 'audio',
                audioData: pendingAudio,
                audioFormat: 'wav'
            });
            contents.push(audioContent);
        }

        // Message erstellen
        var message = litertlm.createMessageProxy({
            role: 'user',
            contents: contents
        });

        conversation.sendMultimodal(message);
    } else {
        // Text: Streaming
        var msg = litertlm.createMessageProxy({
            role: 'user',
            contents: [litertlm.createContentProxy({
                type: 'text',
                text: prompt
            })]
        });

        conversation.sendStream(msg);
    }
}

/**
 * Generierung stoppen
 */
function stopGeneration() {
    if (!conversation) return;
    conversation.cancel();
    isGenerating = false;
    updateInputButtons();
    statusLabel.text = 'Generierung gestoppt.';
}

/**
 * Aufräumen (Reset)
 */
function cleanup() {
    if (conversation) {
        conversation.close();
        conversation = null;
    }

    if (engine) {
        engine.unload();
        engine = null;
    }

    hasLoadedModel = false;
    isGenerating = false;
    isModelLoading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    totalBytes = 0;
    downloadSpeed = 0;
    toolsEnabled = false;

    // UI zurücksetzen
    clearMessages();
    updateInputButtons();
    statusLabel.text = 'Zurückgesetzt. Tippe "Modell laden".';
    loadModelButton.setTitle('Modell laden');
    loadModelButton.enabled = true;

    // Modell-Ladebereich wieder anzeigen
    if (mainWin.getViews().indexOf(loadModelView) === -1) {
        mainWin.add(loadModelView);
    }
    if (mainWin.getViews().indexOf(downloadView) === -1) {
        mainWin.add(downloadView);
    }
}

/**
 * Kamera öffnen
 */
function openCamera() {
    Ti.Media.openCamera({
        success: function(event) {
            pendingImage = event.media;
            statusLabel.text = 'Foto aufgenommen. Tippe Senden.';

            // Miniatur anzeigen
            if (!Ti.UI.createImageView) {
                // Fallback
            }
        },
        cancel: function() {
            statusLabel.text = 'Kamera abgebrochen.';
        },
        error: function(error) {
            Ti.API.error('Kamera-Fehler: ' + error);
            statusLabel.text = 'Kamera-Fehler: ' + error;
        }
    });
}

/**
 * Fotomediathek öffnen
 */
function openPhotoLibrary() {
    var gallery = Ti.UI.createPicker({
        type: Ti.UI.createPicker.GALLERY
    });

    gallery.addEventListener('complete', function(e) {
        if (e.success) {
            pendingImage = e.media;
            statusLabel.text = 'Foto ausgewählt. Tippe Senden.';
        }
    });

    gallery.show();
}

/**
 * Stimme aufnehmen / stoppen
 */
function toggleVoiceRecording() {
    if (isRecording) {
        // Aufnahme stoppen
        isRecording = false;
        statusLabel.text = 'Aufnahme gestoppt.';

        // Audio-Daten vom Recorder erhalten
        // (Hier vereinfacht – in der Praxis müsste der Recorder-State gehalten werden)
        pendingAudio = null; // placeholder
    } else {
        // Aufnahme starten
        isRecording = true;
        statusLabel.text = 'Nehme auf... Tippe Mikro-Button zum Stoppen.';

        // Audio-Recorder starten
        var audioSession = Ti.Media.AudioSession;
        audioSession.setCategory(Ti.Media.AudioSession.RECORD);
        audioSession.start();

        // Recorder initialisieren
        var recordingPath = Ti.Filesystem.applicationStorageDirectory + 'temp_recording.wav';
        var recorder = Ti.Media.createAudioRecorder({
            outputFormat: Ti.Media.AUDIO_FORMAT_LINEAR_AUDIO,
            sampleRate: 16000,
            channels: 1,
            bitRate: 16,
            output: Ti.Filesystem.getFile(recordingPath)
        });

        recorder.start();

        // Button ändern
        plusButton.title = "■";  // Stop-Icon

        // Stop-Event
        plusButton.addEventListener('click', function() {
            recorder.stop();
            recorder.release();
            isRecording = false;
            plusButton.title = "+";

            // Audio-Daten laden
            var audioFile = Ti.Filesystem.getFile(recordingPath);
            if (audioFile.exists()) {
                pendingAudio = audioFile.read();
                statusLabel.text = 'Audio aufgenommen. Tippe Senden.';
            }
        });
    }
}

/**
 * Tools-Blatt anzeigen
 */
function showToolsSheet() {
    var options = ['Wetter-Tool aktivieren', 'Rechner-Tool aktivieren', 'Würfel-Tool aktivieren', 'Alle Tools', 'Tools deaktivieren', 'Abbrechen'];

    var dialog = Ti.UI.createOptionDialog({
        title: 'Werkzeuge',
        options: options,
        cancel: 5,
        destructive: 4
    });

    dialog.addEventListener('click', function(e) {
        if (e.index === 0) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Wetter-Tool: ' + (toolsEnabled ? 'AKTIV' : 'DEAKTIV');
        } else if (e.index === 1) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Rechner-Tool: ' + (toolsEnabled ? 'AKTIV' : 'DEAKTIV');
        } else if (e.index === 2) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Würfel-Tool: ' + (toolsEnabled ? 'AKTIV' : 'DEAKTIV');
        } else if (e.index === 3) {
            toolsEnabled = true;
            statusLabel.text = 'Alle Tools AKTIV';
        } else if (e.index === 4) {
            toolsEnabled = false;
            statusLabel.text = 'Alle Tools DEAKTIV';
        }
    });

    dialog.show();
}

/**
 * Wetter-Tool erstellen
 */
function createWeatherTool() {
    var tool = litertlm.createToolProxy({
        name: 'get_weather',
        description: 'Holt das aktuelle Wetter für eine Stadt. Gibt Temperatur, Bedingung und Luftfeuchtigkeit zurück.',
        parameters: [{
            name: 'city',
            type: 'string',
            description: 'Stadtnamen (z.B. Tokyo, Berlin, London)',
            required: true
        }, {
            name: 'unit',
            type: 'string',
            description: 'Temperatureinheit: celsius oder fahrenheit'
        }]
    });

    tool.executeCallback = function(args, callback) {
        var city = args.city || 'Berlin';
        var unit = args.unit || 'celsius';

        // Simulierte Wetterdaten (basierend auf Stadt-Hash)
        var conditions = ['sonnig', 'bewölkt', 'regnerisch', 'windig', 'schnee'];
        var condition = conditions[Math.abs(city.length * 7) % conditions.length];
        var tempC = 10 + (Math.abs(city.length * 13) % 25);
        var temp = unit === 'fahrenheit' ? Math.round(tempC * 1.8 + 32) : tempC;
        var humidity = 40 + (Math.abs(city.length * 17) % 50);

        callback({
            city: city,
            temperature: temp,
            unit: unit === 'fahrenheit' ? '°F' : '°C',
            condition: condition,
            humidity: humidity + '%'
        });
    };

    return tool;
}

/**
 * Rechner-Tool erstellen
 */
function createCalculatorTool() {
    var tool = litertlm.createToolProxy({
        name: 'calculate',
        description: 'Berechnet einen einfachen mathematischen Ausdruck. Unterstützt +, -, *, /.',
        parameters: [{
            name: 'expression',
            type: 'string',
            description: 'Mathematischer Ausdruck (z.B. "24 * 365")',
            required: true
        }]
    });

    tool.executeCallback = function(args, callback) {
        var expr = args.expression || '';
        try {
            // Einfache Berechnung (sicherer als eval)
            var result = Function('return (' + expr + ')')();
            callback({
                expression: expr,
                result: result
            });
        } catch (e) {
            callback({
                expression: expr,
                error: 'Konnte nicht berechnen'
            });
        }
    };

    return tool;
}

/**
 * Würfel-Tool erstellen
 */
function createDiceTool() {
    var tool = litertlm.createToolProxy({
        name: 'roll_dice',
        description: 'Wurft einen oder mehrere Würfel und gibt die Ergebnisse zurück.',
        parameters: [{
            name: 'count',
            type: 'integer',
            description: 'Anzahl der Würfel (Standard: 1)'
        }, {
            name: 'sides',
            type: 'integer',
            description: 'Anzahl der Seiten pro Würfel (Standard: 6)'
        }]
    });

    tool.executeCallback = function(args, callback) {
        var count = Math.min((args.count || 1), 20);
        var sides = Math.max((args.sides || 6), 2);
        var rolls = [];
        var total = 0;

        for (var i = 0; i < count; i++) {
            var roll = Math.floor(Math.random() * sides) + 1;
            rolls.push(roll);
            total += roll;
        }

        callback({
            rolls: rolls,
            total: total,
            dice: count + 'd' + sides
        });
    };

    return tool;
}

/**
 * Bytes formatieren (KB, MB, GB)
 */
function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    var abs = Math.abs(bytes);
    if (abs < 1024) return bytes + ' B';
    if (abs < 1024 * 1024) return (abs / 1024).toFixed(1) + ' KB';
    if (abs < 1024 * 1024 * 1024) return (abs / (1024 * 1024)).toFixed(1) + ' MB';
    return (abs / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// ============================================================
// Stream-Event-Listener
// ============================================================

function setupStreamListeners() {
    if (!conversation) return;

    // Stream-Start
    conversation.addEventListener('streamstart', function(e) {
        statusLabel.text = 'Generiere...';
    });

    // Token empfangen
    conversation.addEventListener('token', function(e) {
        // Token an letzte Modell-Nachricht anhängen
        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            // Tags von Gemma 4 entfernen
            var cleanedText = stripGemmaTags(lastMsg.text + e.token);
            updateMessage(messages.length - 1, cleanedText);
        }
    });

    // Stream abgeschlossen
    conversation.addEventListener('streamcomplete', function(e) {
        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            var cleanedText = stripGemmaTags(e.result || '');
            updateMessage(messages.length - 1, cleanedText);
        }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Antwort bereit.';
    });

    // Stream-Fehler
    conversation.addEventListener('streamerror', function(e) {
        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            updateMessage(messages.length - 1, 'Fehler: ' + e.message);
        }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Streaming-Fehler.';
    });

    // Stream beendet
    conversation.addEventListener('streamend', function(e) {
        statusLabel.text = 'Streaming beendet.';
    });

    // Nachricht vollständig
    conversation.addEventListener('messagecomplete', function(e) {
        var msg = e.message;
        if (msg && msg.role === 'model') {
            // Antwort aktualisieren
            var lastMsg = messages[messages.length - 1];
            if (lastMsg && lastMsg.role === 'model') {
                var text = '';
                if (msg.contents && msg.contents.length > 0) {
                    text = msg.contents[0].text || '';
                }
                var cleanedText = stripGemmaTags(text);
                updateMessage(messages.length - 1, cleanedText);
            }
        }
        isGenerating = false;
        updateInputButtons();
    });

    // Nachricht-Fehler
    conversation.addEventListener('messageerror', function(e) {
        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            updateMessage(messages.length - 1, 'Fehler: ' + e.message);
        }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Nachrichten-Fehler.';
    });
}

/**
 * Gemma-4-Tags entfernen (<|turn>model, <start_of_turn>, etc.)
 */
function stripGemmaTags(text) {
    if (!text) return '';

    var tags = [
        '<|turn>model',
        '<|turn>user',
        '<|turn>system',
        '<|turn>',
        '<turn|>',
        '<start_of_turn>model',
        '<start_of_turn>user',
        '<start_of_turn>',
        '<end_of_turn>',
        '<|channel>',
        '<channel|>',
        '<|think|>',
        '<eos>',
        '<bos>'
    ];

    var result = text;
    for (var i = 0; i < tags.length; i++) {
        var regex = new RegExp(tags[i], 'g');
        result = result.replace(regex, '');
    }

    // Thinking blocks entfernen: <|channel>...<channel|>
    while (result.indexOf('<|channel>') !== -1) {
        var start = result.indexOf('<|channel>');
        var end = result.indexOf('<channel|>', start);
        if (end === -1) {
            result = result.substring(0, start);
        } else {
            result = result.substring(0, start) + result.substring(end + 10);
        }
    }

    // Leerzeichen bereinigen
    result = result.replace(/\s+/g, ' ').trim();
    return result;
}

// ============================================================
// UI zusammenbauen
// ============================================================

mainWin.add(headerView);
mainWin.add(chatTableView);
mainWin.add(downloadView);
mainWin.add(loadModelView);
mainWin.add(inputBar);

// Initiale Message-Liste rendern
//renderAllMessages();

// Fenster anzeigen
mainWin.open();

// Debug-Info
Ti.API.info('TitaniumLiteRTLM ChatDemo geladen');
Ti.API.info('Modul-Version: ' + litertlm.getVersion());
Ti.API.info('Verfügbare Methoden: createEngine, createConversation, createDownloader, ...');
