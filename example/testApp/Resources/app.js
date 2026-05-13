/**
 * TitaniumLiteRTLM – Complete ChatDemo Example
 *
 * This example demonstrates all features of the de.marcbender.litertlm module:
 * - Model download and management
 * - Engine initialization (CPU/GPU)
 * - Text generation
 * - Streaming output
 * - Conversation with history
 * - Tool calling (weather, calculator, dice)
 * - Multimodal input (camera, photo library)
 * - Voice/audio input
 * - Error handling
 *
 */

// ============================================================
// Load modules
// ============================================================
var litertlm = require('de.marcbender.litertlm');
var TiBubble = require('de.marcbender.bubbleview'); 

// ============================================================
// Global status and service variables
// ============================================================
var hasLoadedModel = false;
var isGenerating = false;
var isModelLoading = false;
var selectedBackend = 'cpu'; // 'cpu' or 'gpu'
var toolsEnabled = true;
var pendingImage = null;
var pendingAudio = null;
var isRecording = false;

// Conversation and engine references (set by Titanium)
var engine = null;
var conversation = null;
var downloader = null;

// Download progress
var downloadProgress = 0;
var downloadedBytes = 0;
var totalBytes = 0;
var downloadSpeed = 0;

// Model info (Gemma 4 E2B from HuggingFace)
var modelInfo = {
    name: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    expectedSize: 2583085056, // ~2.4 GB
    fileName: 'gemma-4-E2B-it.litertlm'
};

// System prompt
var systemPrompt = 'You are a helpful, friendly AI assistant running entirely on-device via LiteRTLM Swift SDK and Google\'s Gemma 4. You are part of a demo app that showcases on-device LLM inference. Be concise, helpful, and conversational. You can see images the user sends. Keep responses short unless asked for detail.';

// ============================================================
// Create UI components
// ============================================================

// Main window
var mainWin = Ti.UI.createWindow({
    backgroundColor: '#1a1a2e',
    height: Ti.UI.FILL,
    width: Ti.UI.FILL,
    top:0,
    bottom:0
});

// Header area
var headerView = Ti.UI.createView({
    layout: 'horizontal',
    height: 140,
    backgroundColor: '#16213e',
    top: 50,
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
    text: 'Ready – Tap "Load Model"',
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
// Chat message list (TableView)
// ============================================================
var messages = []; // { role: 'user'|'model'|'system', text: '', image: null }
var loadModelViewAdded = false;
var downloadViewAdded = false;

var chatTableView = Ti.UI.createTableView({
    backgroundColor: '#fff',
    layout: 'vertical',
    top: 160,
    bottom: 80,
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

    // Scroll to last entry
    if (messages.length > 0) {
        chatTableView.scrollToIndex(messages.length - 1);
    }
}

function createMessageRow(msg, index) {

    var row = Ti.UI.createTableViewRow({
        height: Ti.UI.SIZE,
        width: Ti.UI.FILL,
        hasUnread: false
    });

    var container = Ti.UI.createView({
        height: Ti.UI.SIZE,
        width: Ti.UI.FILL,
        left:5,
        right:5,
        top: 5,
        bottom: 5
    });

    if (msg.role === 'system') {
        // System message (centered, small text)
        var systemLabel = Ti.UI.createLabel({
            text: msg.text,
            color: '#a0a0a0',
            font: { fontSize: 11, fontStyle: 'italic' },
            textAlign: 'center',
            width: '100%',
            height: Ti.UI.SIZE,
            top: 5,
            bottom: 5
        });
        row.add(systemLabel);
        return row;
    }

    // User message on right, model message on left
    var isUser = msg.role === 'user';
    Ti.API.info('createMessageRow:'+msg.role+' isUser:'+isUser);

    if (isUser){
        var bubble = TiBubble.createBubble({
            right: 5,
            layout: 'vertical',
            width: Ti.UI.SIZE, // just fit from contained label
            maxWidth: '80%',
            height: Ti.UI.SIZE, // just fit from contained label
            bubbleColor: isUser ? '#e94560' : '#16213e', // default: #fff
            bubbleRadius: 12, // default: 20
            bubbleBeak: TiBubble.BUBBLE_BEAK_RIGHT,
            bubbleBeakVertical: TiBubble.BUBBLE_BEAK_LOWER, // default BUBBLE_BEAK_LOWER
            tailWidth: 8,       // Width of the tail base (dp)
            tailLength: 12,     // Length of the tail tip (dp)
            tailCurveY: 8,      // Curve intensity of the tail (dp)
        });
    }
    else {
        var bubble = TiBubble.createBubble({
            left: 5,
            layout: 'vertical',
            width: Ti.UI.SIZE, // just fit from contained label
            maxWidth: '80%',
            height: Ti.UI.SIZE, // just fit from contained label
            bubbleColor: isUser ? '#e94560' : '#16213e', // default: #fff
            bubbleRadius: 12, // default: 20
            bubbleBeak: TiBubble.BUBBLE_BEAK_LEFT,
            bubbleBeakVertical: TiBubble.BUBBLE_BEAK_LOWER,
            tailWidth: 8,       // Width of the tail base (dp)
            tailLength: 12,     // Length of the tail tip (dp)
            tailCurveY: 8,      // Curve intensity of the tail (dp)
        });
    }

    // Show image if present
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

    // Show text
    var textLabel = Ti.UI.createLabel({
        text: msg.text || (isUser ? '[Photo]' : '[Generating...]'),
        color: isUser ? '#e0e0e0' : '#e0e0e0',
        font: { fontSize: 14, fontWeight: 'normal' },
        textAlign: 'left',
        height: Ti.UI.SIZE,
        width: Ti.UI.SIZE,
        top: msg.image ? 10 : 10,
        left: isUser ? 10 : 20,
        right: isUser ? 20 : 10,
        bottom: 10,
        wordWrap: true,
        selectionColor: '#a0a0a0'
    });
    bubble.add(textLabel);

    container.add(bubble);
    row.add(container);
    return row;
}

// ============================================================
// Download progress area
// ============================================================
var downloadView = Ti.UI.createView({
    layout: 'vertical',
    height: 44,
    top: 160,
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
// Model loading area
// ============================================================
var loadModelView = Ti.UI.createView({
    layout: 'vertical',
    height: 60,
    backgroundColor:'green',
    top: 100,
    left: 0,
    right: 0,
});

// Backend selection
var backendPicker = Ti.UI.createView({
    layout: 'horizontal',
    bottom: 30,
    height: 40,
    width: Ti.UI.FILL
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


var loadModelButton = Ti.UI.createButton({
    title: 'Load Model',
    font: { fontSize: 16, fontWeight: 'bold' },
    color: '#ffffff',
    backgroundColor: '#e94560',
    borderRadius: 8,
    width: 100,
    height: 36
});


backendPicker.add(cpuButton);

backendPicker.add(loadModelButton);

backendPicker.add(gpuButton);

var backendLabel = Ti.UI.createLabel({
    text: 'Select backend:',
    color: '#e0e0e0',
    font: { fontSize: 13, fontWeight: 'bold' },
    top: 5,
    left: 10
});

var backendInfo = Ti.UI.createLabel({
    text: 'CPU: Compatible with all devices\nGPU: Faster inference via Metal',
    color: '#a0a0a0',
    font: { fontSize: 10 },
    top: 5,
    left: 10,
    right: 10,
    height: 30
});


loadModelView.add(backendLabel);
loadModelView.add(backendPicker);
loadModelView.add(backendInfo);

// ============================================================
// Input area
// ============================================================
var inputBar = Ti.UI.createView({
    layout: 'horizontal',
    height: 60,
    width:Ti.UI.FILL,
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'red'
});

var inputTextField = Ti.UI.createTextField({
    hint: 'Enter message...',
    color: '#000000',
    backgroundColor: '#eaeaea',
    borderColor: '#2a2a4a',
    borderWidth: 1,
    borderRadius: 20,
    height: 36,
    width: '80%',
    left: 5,
    returnKeyType: Ti.UI.RETURNKEY_SEND,
    keyboardToolbar: null
});

// Plus button: shows an option dialog (compatible with Titanium 13.x)
var plusButton = Ti.UI.createButton({
    title: '+',
    font: { fontSize: 20, fontWeight: 'bold' },
    color: '#e0e0e0',
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#2a2a4a'
});

// Plus button shows options (photo, audio)
plusButton.addEventListener("click", function() {
    var options = ["Take photo", "Photo library", "Record voice", "Cancel"];
    var dialog = Ti.UI.createOptionDialog({
        title: "Input",
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
    title: '>',
    font: { fontSize: 20, fontWeight: 'bold' },
    color: '#e0e0e0',
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#2a2a4a'
});

var stopButton = Ti.UI.createButton({
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
// Event listeners for buttons
// ============================================================

// Backend selection
cpuButton.addEventListener('click', function() {
    selectedBackend = 'cpu';
    cpuButton.backgroundColor = '#e94560';
    cpuButton.color = '#ffffff';
    gpuButton.backgroundColor = '#2a2a4a';
    gpuButton.color = '#a0a0a0';
    backendInfo.text = 'Compatible with all devices';
});

gpuButton.addEventListener('click', function() {
    selectedBackend = 'gpu';
    gpuButton.backgroundColor = '#e94560';
    gpuButton.color = '#ffffff';
    cpuButton.backgroundColor = '#2a2a4a';
    cpuButton.color = '#a0a0a0';
    backendInfo.text = 'Faster inference via Metal';
});

// Load model
loadModelButton.addEventListener('click', function() {
    if (isModelLoading) return;
    loadModel();
});

// Send button
sendButton.addEventListener('click', function() {
    if (isGenerating) return;
    sendMessage();
});

// Stop-Button
stopButton.addEventListener('click', function() {
    stopGeneration();
});

// Tools button
toolsButton.addEventListener('click', function() {
    showToolsSheet();
});

// Reset button
resetButton.addEventListener('click', function() {
    cleanup();
});

// ============================================================
// Main functions
// ============================================================

/**
 * Load model (download + engine initialization)
 */
function loadModel() {
    if (isModelLoading || hasLoadedModel) return;

    isModelLoading = true;
    loadModelButton.title = 'Loading...';
    loadModelButton.enabled = false;
    statusLabel.text = 'Loading model...';

    // Step 1: Create downloader
    var modelsDir = Ti.Filesystem.applicationDataDirectory + 'models/';
    var fs = Ti.Filesystem.getFile(modelsDir);
    if (!fs.exists()) {
        fs.createDirectory();
    }

    Ti.API.info('createDownloader');

    downloader = litertlm.createDownloader({
        modelsDirectory: modelsDir
    });
    Ti.API.info('after createDownloader');

    Ti.API.info('before downloader addEventListener');
    // Download progress
    downloader.addEventListener('downloadprogress', function(e) {
        downloadProgress = e.progress || 0;
        downloadedBytes = e.bytesDownloaded || 0;
        totalBytes = e.totalBytes || modelInfo.expectedSize;
        Ti.API.info('downloadprogress');

        // Calculate speed
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

        // Show progress
        var percent = Math.round(downloadProgress * 100);
        progressLabel.text = formatBytes(downloadedBytes) + ' / ' + formatBytes(totalBytes) +
            '  •  ' + formatBytes(Math.round(downloadSpeed)) + '/s';
        progressBar.value = downloadProgress;
        statusLabel.text = 'Download: ' + percent + '%';
    });

    downloader.addEventListener('downloadcomplete', function(e) {
        statusLabel.text = 'Download complete. Initializing engine...';
        initializeEngine();
    });

    downloader.addEventListener('downloaderror', function(e) {
        statusLabel.text = 'Download error: ' + e.message;
        isModelLoading = false;
        loadModelButton.title = 'Load Model';
        loadModelButton.enabled = true;
    });
    Ti.API.info('after downloader addEventListener');


    Ti.API.info('downloader: '+JSON.stringify(downloader));


    // Check if model is already downloaded
    Ti.API.info('before exists downloader.isDownloaded ');
    var exists = downloader.isDownloaded(modelInfo);
    Ti.API.info('after exists downloader.isDownloaded '+ exists);

    if (!exists) {
        statusLabel.text = 'Downloading model...';
        Ti.API.info('before downloader download');
        downloader.download(modelInfo);
        Ti.API.info('after downloader download');

    } else {
        statusLabel.text = 'Model already present. Initializing engine...';
        // Go directly to engine initialization
        Ti.API.info('before initializeEngine');
        initializeEngine();
    }
}

var lastDownloadTime = 0;
var lastDownloadedBytes = 0;

/**
 * Initialize engine
 */
function initializeEngine() {
    statusLabel.text = 'Initializing engine (' + selectedBackend.toUpperCase() + ')...';

    var cacheDir = Ti.Filesystem.applicationCacheDirectory + '/litertlm_cache/';
    var cacheFile = Ti.Filesystem.getFile(cacheDir);
    if (!cacheFile.exists()) {
        cacheFile.createDirectory();
    }

    // Engine configuration
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
 * Engine created event
 */
litertlm.addEventListener('enginecreated', function(e) {
    engine = e.engine;
    statusLabel.text = 'Engine ready. Creating conversation...';

    // Create conversation
    var convConfig = litertlm.createConversationConfigProxy({
        systemPrompt: systemPrompt,
        maxOutputTokens: 1024,
        samplerType: 'balanced'
    });

    if (toolsEnabled) {
        // Add tools
        var weatherTool = createWeatherTool();
        var calculatorTool = createCalculatorTool();
        var diceTool = createDiceTool();

        convConfig.toolExecutionMode = 'auto';
        convConfig.tools = [weatherTool, calculatorTool, diceTool];
    }

    engine.createConversationWithConfig(convConfig);
});

/**
 * Conversation created event
 */
litertlm.addEventListener('conversationcreated', function(e) {
    Ti.API.info('conversationcreated Titanium');

    conversation = e.conversation;
    Ti.API.info('conversation object: ' + conversation + ', has sendStream: ' + (typeof conversation.sendStream));
    setupStreamListeners();
    hasLoadedModel = true;
    isModelLoading = false;
    loadModelButton.title = 'Load Model';
    loadModelButton.enabled = true;
    statusLabel.text = 'Ready to chat. Send a message!';

    // Add system message
    addMessage('system', 'Ready to chat. Send a message, photo, or use voice.');

    // Hide model loading area
    mainWin.remove(loadModelView);
    mainWin.remove(downloadView);
    loadModelViewAdded = false;
    downloadViewAdded = false;
});

/**
 * Send message
 */
function sendMessage() {
    Ti.API.info('sendMessage');

    if (!conversation || isGenerating) return;

    var text = inputTextField.value || '';
    var hasMedia = pendingImage !== null || pendingAudio !== null;

    if (!text && !hasMedia) return;

    // Show user message
    var displayText = text;
    if (!text && pendingImage) {
        displayText = '[Photo]';
    } else if (!text && pendingAudio) {
        displayText = '[Voice message]';
    }

    addMessage('user', displayText, pendingImage);
    inputTextField.value = '';
    pendingImage = null;
    pendingAudio = null;

    // Placeholder for model response
    addMessage('model', '');

    // Prepare prompt
    var prompt = text ||
        (pendingImage ? 'Describe what you see in this image.' :
         pendingAudio ? 'React to this voice message.' : '');

    var hasMediaInput = pendingImage !== null || pendingAudio !== null;

    isGenerating = true;
    updateInputButtons();

    if (hasMediaInput) {
        // Multimodal input
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

        // Create message
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
 * Stop generation
 */
function stopGeneration() {
    if (!conversation) return;
    conversation.cancel();
    isGenerating = false;
    updateInputButtons();
    statusLabel.text = 'Generation stopped.';
}

/**
 * Cleanup (Reset)
 */
function cleanup() {
    if (conversation) {
        litertlm.closeConversation(conversation);
        conversation = null;
    }

    if (engine) {
        litertlm.unloadEngine(engine);
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

    // Reset UI
    clearMessages();
    updateInputButtons();
    statusLabel.text = 'Reset. Tap "Load Model".';
    loadModelButton.title = 'Load Model';
    loadModelButton.enabled = true;

    // Show model loading area again
    if (!loadModelViewAdded) {
        mainWin.add(loadModelView);
        loadModelViewAdded = true;
    }
    if (!downloadViewAdded) {
        mainWin.add(downloadView);
        downloadViewAdded = true;
    }
}

/**
 * Open camera
 */
function openCamera() {
    Ti.Media.openCamera({
        success: function(event) {
            pendingImage = event.media;
            statusLabel.text = 'Photo taken. Tap Send.';

            // Show thumbnail
            if (!Ti.UI.createImageView) {
                // Fallback
            }
        },
        cancel: function() {
            statusLabel.text = 'Camera cancelled.';
        },
        error: function(error) {
            Ti.API.error('Camera error: ' + error);
            statusLabel.text = 'Camera error: ' + error;
        }
    });
}

/**
 * Open photo library
 */
function openPhotoLibrary() {
    var gallery = Ti.UI.createPicker({
        type: Ti.UI.createPicker.GALLERY
    });

    gallery.addEventListener('complete', function(e) {
        if (e.success) {
            pendingImage = e.media;
            statusLabel.text = 'Photo selected. Tap Send.';
        }
    });

    gallery.show();
}

/**
 * Record/stop voice
 */
function toggleVoiceRecording() {
    if (isRecording) {
        // Stop recording
        isRecording = false;
        statusLabel.text = 'Recording stopped.';

        // Get audio data from recorder
        // (Simplified here - in practice the recorder state must be maintained)
        pendingAudio = null; // placeholder
    } else {
        // Start recording
        isRecording = true;
        statusLabel.text = 'Recording... Tap mic button to stop.';

        // Start audio recorder
        var audioSession = Ti.Media.AudioSession;
        audioSession.setCategory(Ti.Media.AudioSession.RECORD);
        audioSession.start();

        // Initialize recorder
        var recordingPath = Titanium.Filesystem.applicationDataDirectory + 'temp_recording.wav';
        var recorder = Ti.Media.createAudioRecorder({
            outputFormat: Ti.Media.AUDIO_FORMAT_LINEAR_AUDIO,
            sampleRate: 16000,
            channels: 1,
            bitRate: 16,
            output: Ti.Filesystem.getFile(recordingPath)
        });

        recorder.start();

        // Change button
        plusButton.title = "■";  // Stop-Icon

        // Stop event
        plusButton.addEventListener('click', function() {
            recorder.stop();
            recorder.release();
            isRecording = false;
            plusButton.title = "+";

            // Load audio data
            var audioFile = Ti.Filesystem.getFile(recordingPath);
            if (audioFile.exists()) {
                pendingAudio = audioFile.read();
                statusLabel.text = 'Audio recorded. Tap Send.';
            }
        });
    }
}

/**
 * Show tools sheet
 */
function showToolsSheet() {
    var options = ['Enable weather tool', 'Enable calculator tool', 'Enable dice tool', 'All tools', 'Disable tools', 'Cancel'];

    var dialog = Ti.UI.createOptionDialog({
        title: 'Tools',
        options: options,
        cancel: 5,
        destructive: 4
    });

    dialog.addEventListener('click', function(e) {
        if (e.index === 0) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Weather tool: ' + (toolsEnabled ? 'ON' : 'OFF');
        } else if (e.index === 1) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Calculator tool: ' + (toolsEnabled ? 'ON' : 'OFF');
        } else if (e.index === 2) {
            toolsEnabled = !toolsEnabled;
            statusLabel.text = 'Dice tool: ' + (toolsEnabled ? 'ON' : 'OFF');
        } else if (e.index === 3) {
            toolsEnabled = true;
            statusLabel.text = 'All tools ON';
        } else if (e.index === 4) {
            toolsEnabled = false;
            statusLabel.text = 'All tools OFF';
        }
    });

    dialog.show();
}

/**
 * Create weather tool
 */
function createWeatherTool() {
    var tool = litertlm.createToolProxy({
        name: 'get_weather',
        description: 'Gets the current weather for a city. Returns temperature, condition and humidity.',
        parameters: [{
            name: 'city',
            type: 'string',
            description: 'City name (e.g. Tokyo, Berlin, London)',
            required: true
        }, {
            name: 'unit',
            type: 'string',
            description: 'Temperatureinheit: celsius oder fahrenheit'
        }]
    });

    tool.executeCallback = function(args) {
        var city = args.city || 'Berlin';
        var unit = args.unit || 'celsius';

        // Simulated weather data (based on city hash)
        var conditions = ['sunny', 'cloudy', 'rainy', 'windy', 'snowy'];
        var condition = conditions[Math.abs(city.length * 7) % conditions.length];
        var tempC = 10 + (Math.abs(city.length * 13) % 25);
        var temp = unit === 'fahrenheit' ? Math.round(tempC * 1.8 + 32) : tempC;
        var humidity = 40 + (Math.abs(city.length * 17) % 50);

        return {
            city: city,
            temperature: temp,
            unit: unit === 'fahrenheit' ? '°F' : '°C',
            condition: condition,
            humidity: humidity + '%'
        };
    };

    return tool;
}

/**
 * Create calculator tool
 */
function createCalculatorTool() {
    var tool = litertlm.createToolProxy({
        name: 'calculate',
        description: 'Calculates a simple mathematical expression. Supports +, -, *, /.',
        parameters: [{
            name: 'expression',
            type: 'string',
            description: 'Mathematical expression (e.g. "24 * 365")',
            required: true
        }]
    });

    tool.executeCallback = function(args) {
        var expr = args.expression || '';
        try {
            // Simple calculation (safer than eval)
            var result = Function('return (' + expr + ')')();
            return {
                expression: expr,
                result: result
            };
        } catch (e) {
            return {
                expression: expr,
                error: 'Could not calculate'
            };
        }
    };

    return tool;
}

/**
 * Create dice tool
 */
function createDiceTool() {
    var tool = litertlm.createToolProxy({
        name: 'roll_dice',
        description: 'Rolls one or more dice and returns the results.',
        parameters: [{
            name: 'count',
            type: 'integer',
            description: 'Number of dice (default: 1)'
        }, {
            name: 'sides',
            type: 'integer',
            description: 'Number of sides per die (default: 6)'
        }]
    });

    tool.executeCallback = function(args) {
        var count = Math.min((args.count || 1), 20);
        var sides = Math.max((args.sides || 6), 2);
        var rolls = [];
        var total = 0;

        for (var i = 0; i < count; i++) {
            var roll = Math.floor(Math.random() * sides) + 1;
            rolls.push(roll);
            total += roll;
        }

        return {
            rolls: rolls,
            total: total,
            dice: count + 'd' + sides
        };
    };

    return tool;
}

/**
 * Format bytes (KB, MB, GB)
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
// Stream event listeners
// ============================================================

function setupStreamListeners() {
    if (!conversation) return;

    // Stream start
    conversation.addEventListener('streamstart', function(e) {
                       Ti.API.info('streamstart');

        statusLabel.text = 'Generating...';
    });

    // Token received
    conversation.addEventListener('token', function(e) {
               Ti.API.info('token');

        // Append token to last model message
        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            // Remove Gemma 4 tags
            var cleanedText = stripGemmaTags(lastMsg.text + e.token);
            updateMessage(messages.length - 1, cleanedText);
        }
    });

    // Stream complete
    conversation.addEventListener('streamcomplete', function(e) {
        Ti.API.info('streamcomplete');

        // var lastMsg = messages[messages.length - 1];
        // if (lastMsg && lastMsg.role === 'model') {
        //     var cleanedText = stripGemmaTags(e.result || '');
        //     updateMessage(messages.length - 1, cleanedText);
        // }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Response ready.';
    });

    // Stream error
    conversation.addEventListener('streamerror', function(e) {
                Ti.API.info('streamerror');

        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            updateMessage(messages.length - 1, 'Error: ' + e.message);
        }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Streaming error.';
    });

    // Stream ended
    conversation.addEventListener('streamend', function(e) {
                        Ti.API.info('streamend');

        statusLabel.text = 'Streaming ended.';
    });

    // Tool call detected (automatic: executed immediately)
    conversation.addEventListener('toolcall', function(e) {
        Ti.API.info('toolcall: ' + e.name + ', args: ' + JSON.stringify(e.arguments));
        statusLabel.text = 'Calling tool: ' + e.name + '...';
    });

    // Tool result (automatic: result is streamed as tokens)
    conversation.addEventListener('toolresult', function(e) {
        Ti.API.info('toolresult: ' + JSON.stringify(e.result));
        statusLabel.text = 'Tool result received...';
    });

    // Tool error
    conversation.addEventListener('toolerror', function(e) {
        Ti.API.info('toolerror: ' + e.message);
        statusLabel.text = 'Tool error: ' + e.message;
    });

    // Message complete
    conversation.addEventListener('messagecomplete', function(e) {
                                Ti.API.info('messagecomplete');

        var msg = e.message;
        if (msg && msg.role === 'model') {
            // Update response
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

    // Message error
    conversation.addEventListener('messageerror', function(e) {
                                        Ti.API.info('messageerror');

        var lastMsg = messages[messages.length - 1];
        if (lastMsg && lastMsg.role === 'model') {
            updateMessage(messages.length - 1, 'Error: ' + e.message);
        }
        isGenerating = false;
        updateInputButtons();
        statusLabel.text = 'Message error.';
    });
}

/**
 * Remove Gemma-4 tags (<|turn>model, <start_of_turn>, etc.)
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

    // Remove thinking blocks: <|channel>...<channel|>
    while (result.indexOf('<|channel>') !== -1) {
        var start = result.indexOf('<|channel>');
        var end = result.indexOf('<channel|>', start);
        if (end === -1) {
            result = result.substring(0, start);
        } else {
            result = result.substring(0, start) + result.substring(end + 10);
        }
    }

    // Clean up whitespace
    result = result.replace(/\s+/g, ' ').trim();
    return result;
}

// ============================================================
// Assemble UI
// ============================================================

mainWin.add(headerView);
mainWin.add(chatTableView);
mainWin.add(downloadView);
        downloadViewAdded = true;
mainWin.add(loadModelView);
        loadModelViewAdded = true;
mainWin.add(inputBar);

// Render initial message list
renderAllMessages();

// Show window
mainWin.open();

// Debug info
Ti.API.info('TitaniumLiteRTLM ChatDemo loaded');
Ti.API.info('Module version: ' + litertlm.getVersion());
Ti.API.info('Available methods: createEngine, createConversation, createDownloader, ...');





