# TitaniumLiteRTLM – API Reference

**Module ID:** `de.marcbender.litertlm`
**Version:** 1.0.0
**Platforms:** iOS (arm64), Android (arm64-v8a, x86_64)
**Titanium SDK:** 13.2.0.GA+

---

## Overview

The `de.marcbender.litertlm` module wraps the full [Google LiteRT-LM SDK](https://github.com/google/litert) as a Titanium module. It enables running Large Language Models (LLMs) directly on-device — no network connection, no cloud dependencies.

### Core Concepts

| Concept | Description |
|---------|-------------|
| **Engine** | Loads a model and manages the inference engine. One engine can hold multiple sessions/conversations. |
| **Session** | A single inference request (one text → one response). Stateless. |
| **Conversation** | A multi-turn conversation with history, system prompt, and tool calling. Stateful. |
| **Downloader** | Downloads models from HuggingFace or other URLs and manages them locally. |
| **Streaming** | Real-time token-by-token output via events. |
| **Tool Calling** | The LLM can call functions in your app and use the results. |

---

## Installation

### Prerequisites

| Platform | Minimum | Recommended |
|----------|---------|-------------|
| **iOS** | 17.0, Titanium SDK 13.2.0.GA, Xcode 15.0 | iOS 17.6+, Xcode 16.x |
| **Android** | 8.0 (API 26), Titanium SDK 13.2.0.GA | Android 10+ |
| **Hardware** | A12 Bionic (iOS) / ARM64 (Android) | A15+ or M-Series (iOS) / Snapdragon 8+ (Android) |

### Install the module

#### iOS

1. Build the module:
   ```bash
   cd ios
   ti build -p ios --build-only
   ```

2. The ZIP is generated in `ios/dist/`. Copy it to your project:
   ```bash
   cp dist/de.marcbender.litertlm-iphone-1.0.0.zip /path/to/your-project/modules/
   ```

#### Android

1. Build the module:
   ```bash
   cd android
   ti build -p android --build-only
   ```

2. The ZIP is generated in `android/dist/`. Copy it to your project:
   ```bash
   cp dist/de.marcbender.litertlm-android-1.0.0.zip /path/to/your-project/modules/
   ```

### Configure tiapp.xml

Add the module for both platforms:

```xml
<modules>
    <module version="1.0.0" platform="ios">de.marcbender.litertlm</module>
    <module version="1.0.0" platform="android">de.marcbender.litertlm</module>
</modules>
```

### Permissions

#### iOS: info.plist

For camera, microphone, and photo library access:

```xml
<property name="ti.android.bundle.url" type="string"></property>
<ios>
    <plist>
        <dict>
            <key>NSCameraUsageDescription</key>
            <string>Capture images for AI recognition</string>
            <key>NSMicrophoneUsageDescription</key>
            <string>Voice input for AI</string>
            <key>NSPhotoLibraryUsageDescription</key>
            <string>Select images from the photo library</string>
        </dict>
    </plist>
</ios>
```

#### Android: AndroidManifest.xml

The module automatically adds `INTERNET` permission. For camera/microphone:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## JavaScript API Reference

### Accessing the Module

```javascript
var litertlm = require('de.marcbender.litertlm');
```

### Main Module Methods

#### `litertlm.getVersion()` → `String`

Returns the module version number.

```javascript
var version = litertlm.getVersion(); // "1.0.0"
```

#### `litertlm.createEngine(arguments)`

Creates and loads an engine with a model.

**Parameters (`arguments`):**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `modelPath` | `String` | *required* | Path to model file or directory |
| `backend` | `String` | `'cpu'` | `'cpu'` or `'gpu'` |
| `maxTokens` | `Int32` | `0` | Maximum number of generated tokens (0 = unlimited) |
| `cacheDir` | `String` | `null` | Cache directory for the model |
| `benchmarkEnabled` | `Boolean` | `false` | Enable benchmarking |
| `logLevel` | `String` | `'warning'` | `'error'`, `'warning'`, `'info'`, `'fatal'`, `'silent'` |

**Events:**

| Name | Description | Payload |
|------|-------------|---------|
| `enginecreated` | Engine loaded successfully | `{ engine: LiteRTLMEngine }` |

**Example:**

```javascript
litertlm.createEngine({
    modelPath: '/path/to/model.gguf',
    backend: 'gpu',
    maxTokens: 1024
});

litertlm.addEventListener('enginecreated', function(e) {
    var engine = e.engine;
    console.log('Status: ' + engine.status);
});
```

#### `litertlm.createEngineWithConfig(config)`

Creates an engine with a configuration object (see `createEngineConfigProxy`).

```javascript
var config = litertlm.createEngineConfigProxy({
    modelPath: '/path/to/model',
    backend: 'gpu'
});
litertlm.createEngineWithConfig(config);
```

#### `litertlm.createEngineConfigProxy(arguments)` → `LiteRTLMEngineConfiguration`

Creates an engine configuration object.

**Parameters (`arguments`):**

| Key | Type | Description |
|-----|------|-------------|
| `modelPath` | `String` | Path to the model |
| `backend` | `String` | `'cpu'` or `'gpu'` |
| `maxTokens` | `Int32` | Maximum tokens |
| `cacheDir` | `String` | Cache directory |
| `benchmarkEnabled` | `Boolean` | Enable benchmarking |
| `logLevel` | `String` | Log level |
| `visionBackend` | `String` | Backend for vision/images |
| `audioBackend` | `String` | Backend for audio |

#### `litertlm.createSessionConfigProxy(arguments)` → `LiteRTLMSessionConfiguration`

Creates a session configuration.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `maxOutputTokens` | `Int32` | Maximum output tokens |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `litertlm.createConversationConfigProxy(arguments)` → `LiteRTLMConversationConfiguration`

Creates a conversation configuration.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `maxOutputTokens` | `Int32` | Maximum output tokens |
| `samplerType` | `String` | Sampler type |
| `tools` | `Array` | List of `LiteRTLMTool` objects |
| `toolExecutionMode` | `String` | `'auto'`, `'required'`, `'disabled'` |
| `maxImageDimension` | `Int` | Maximum image size in pixels |
| `systemPrompt` | `String` | System prompt for the conversation |

#### `litertlm.createSamplerConfigProxy(arguments)` → `LiteRTLMSamplerConfiguration`

Creates a sampler configuration.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `temperature` | `Double` | 0.0–2.0 (low = deterministic, high = creative) |
| `topK` | `Int32` | Consider only the top-K tokens |
| `topP` | `Double` | Nucleus sampling (0.0–1.0) |
| `seed` | `Int32` | Random seed for reproducibility |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `litertlm.createContentProxy(arguments)` → `LiteRTLMContent`

Creates a content object.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Text content |
| `imageData` | `Ti.Blob` | Image data |
| `audioData` | `Ti.Blob` | Audio data |
| `audioFormat` | `String` | Audio format (e.g. `'wav'`, `'mp3'`) |
| `maxDimension` | `Int` | Maximum image dimension |

#### `litertlm.createMessageProxy(arguments)` → `LiteRTLMMessage`

Creates a message (payload) for a conversation.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | List of `LiteRTLMContent` objects |

#### `litertlm.createToolProxy(arguments)` → `LiteRTLMTool`

Creates a tool (function) for tool calling.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Function name |
| `description` | `String` | Description of what the function does |
| `parameters` | `Array` | Parameter definitions |

Each parameter is an object with:

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Parameter name |
| `type` | `String` | `'string'`, `'number'`, `'boolean'`, `'object'`, `'array'` |
| `description` | `String` | Parameter description |
| `required` | `Boolean` | Whether the parameter is required |

#### `litertlm.createDownloader(arguments)` → `LiteRTLMModelDownloader`

Creates a model downloader.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `modelsDirectory` | `String` | Directory for storing models |

**Events:**

| Name | Description | Payload |
|------|-------------|---------|
| `downloadprogress` | Download progress | `{ progress: Float, bytesDownloaded: Int64, totalBytes: Int64 }` |
| `downloadcomplete` | Download completed | `{ modelInfo: LiteRTLMModelInfo }` |
| `downloaderror` | Download error | `{ message: String }` |

#### `litertlm.createModelInfo(arguments)` → `LiteRTLMModelInfo`

Creates a model info object.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Internal model name |
| `displayName` | `String` | Display name |
| `url` | `String` | Download URL |
| `expectedSize` | `Int64` | Expected file size in bytes |
| `fileName` | `String` | File name after download |

#### `litertlm.closeConversation(conv)` → `undefined`

Safely closes a conversation from the module level.

#### `litertlm.unloadEngine(engine)` → `undefined`

Safely unloads an engine from the module level.

---

### LiteRTLMEngine

Represents a loaded LLM engine.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `String` | `'notLoaded'`, `'loading'`, `'ready'`, `'error'` |
| `isReady` | `Boolean` | Whether the engine is ready |
| `lastError` | `String` | Error message or `null` |

#### Methods

##### `engine.load()`

Loads the model into memory.

##### `engine.unload()`

Unloads the model from memory.

##### `engine.createSession(config?)`

Creates a new session.

**Events:** `sessioncreated` with `{ session: LiteRTLMSession }`

##### `engine.createSessionWithConfig(config)`

Creates a session with configuration.

##### `engine.createConversation(config?)`

Creates a new conversation.

**Events:** `conversationcreated` with `{ conversation: LiteRTLMConversation }`

##### `engine.createConversationWithConfig(config)`

Creates a conversation with configuration.

---

### LiteRTLMSession

Represents a single inference session.

> **Note:** The Session API is available on iOS. On Android, use the Conversation API instead.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isActive` | `Boolean` | Whether the session is active |

#### Methods

##### `session.generate(text, config?)`

Generates text as a response.

**Events:**

| Name | Description | Payload |
|------|-------------|---------|
| `generateready` | Generation completed | `{ result: String, benchmarkInfo: Object }` |
| `generateerror` | Error during generation | `{ message: String }` |

##### `session.generateMultimodal(contents, config?)`

Generates a response to multimodal input (text + images + audio).

##### `session.generateStream(text, config?)`

Starts streaming generation.

**Events:**

| Name | Description | Payload |
|------|-------------|---------|
| `streamstart` | Streaming started | `{ sessionId: String }` |
| `token` | New token | `{ token: String }` |
| `streamcomplete` | Streaming completed | `{ result: String, benchmarkInfo: Object }` |
| `streamerror` | Error during streaming | `{ message: String }` |
| `streamend` | Streaming ended | – |

##### `session.collectStream(text, config?)`

Collects all tokens from a streaming response into a result.

##### `session.close()`

Closes the session.

---

### LiteRTLMConversation

Represents a conversation with history.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isActive` | `Boolean` | Whether the conversation is active |
| `history` | `Array` | List of `LiteRTLMMessage` objects |

#### Methods

##### `conversation.send(message, config?)`

Sends a message and receives a response.

**Events:**

| Name | Description | Payload |
|------|-------------|---------|
| `messagecomplete` | Response complete | `{ message: LiteRTLMMessage }` |
| `messageerror` | Error sending message | `{ message: String }` |

##### `conversation.sendMultimodal(message, config?)`

Sends a multimodal message.

##### `conversation.sendStream(message, config?)`

Sends a message with streaming response.

**Events:** Same as session streaming.

##### `conversation.collectStream(message, config?)`

Collects all tokens from a streaming response.

##### `conversation.cancel()`

Cancels the current request.

##### `conversation.close()`

Closes the conversation.

##### `conversation.getHistory()` → `Array`

Returns the conversation history.

---

### LiteRTLMContent

A content object (text, image, or audio).

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Text content |
| `imageData` | `Ti.Blob` | Image data |
| `audioData` | `Ti.Blob` | Audio data |
| `audioFormat` | `String` | Audio format |
| `maxDimension` | `Int` | Maximum dimension |

---

### LiteRTLMMessage

A message in a conversation.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | List of content objects |

---

### LiteRTLMTool

A tool (function) for tool calling.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Function name |
| `description` | `String` | Function description |
| `parameters` | `Array` | Parameter definitions |
| `executeCallback` | `Function` | Callback for execution |

#### executeCallback

The callback is called when the LLM invokes the tool:

```javascript
tool.executeCallback = function(args, callback) {
    // args: parameters the LLM passed
    // callback: function to return the result

    var result = { temperature: 22, condition: 'sunny' };
    callback(result);
};
```

> **Android note:** Tool callbacks are invoked on the UI thread with a 30-second timeout. Long-running callbacks may time out.

---

### LiteRTLMModelInfo

Information about a model.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Model name |
| `displayName` | `String` | Display name |
| `url` | `String` | Download URL |
| `expectedSize` | `Int64` | Expected size in bytes |
| `fileName` | `String` | File name |

---

### LiteRTLMModelDownloader

Model downloader for downloading and managing models.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `modelsDirectory` | `String` | Models directory |

#### Methods

##### `downloader.download(modelInfo)`

Starts downloading a model.

##### `downloader.downloadFrom(url, fileName?, expectedSize?)`

Downloads a model from a URL.

```javascript
downloader.downloadFrom(
    'https://example.com/model.gguf',
    'my-model.gguf',
    5000000000
);
```

##### `downloader.pause()`

Pauses the current download.

##### `downloader.cancel()`

Cancels the download.

##### `downloader.isDownloaded(modelInfo)` → `Boolean`

Checks if a model is downloaded.

##### `downloader.modelPath(modelInfo)` → `String`

Returns the path to the model.

##### `downloader.deleteModel(modelInfo)`

Deletes a downloaded model.

##### `downloader.deleteModelByFileName(fileName)`

Deletes a model by file name.

---

## Usage Notes

### Model Download

The module supports downloading models via HTTP/HTTPS from HuggingFace or other sources:

```javascript
var downloader = litertlm.createDownloader({
    modelsDirectory: Ti.Filesystem.applicationDataDirectory + 'models/'
});

var modelInfo = litertlm.createModelInfo({
    name: 'gemma-4-e2b',
    displayName: 'Gemma 4 E2B',
    url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    expectedSize: 2583085056,
    fileName: 'gemma-4-E2B-it.litertlm'
});

downloader.download(modelInfo);
```

### Stream Processing

```javascript
session.generateStream('Tell me a story.');

session.addEventListener('token', function(e) {
    outputText += e.token;
    label.text = outputText; // Live UI update
});

session.addEventListener('streamcomplete', function(e) {
    console.log('Response: ' + e.result);
});
```

### Tool Calling

```javascript
var tool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Gets the current weather for a city',
    parameters: [{
        name: 'city',
        type: 'string',
        description: 'City name',
        required: true
    }]
});

tool.executeCallback = function(args, callback) {
    var weather = getWeatherFromAPI(args.city);
    callback(weather);
};

var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'You are a helpful assistant.',
    tools: [tool],
    toolExecutionMode: 'auto'
});

engine.createConversationWithConfig(config);
```

### Error Handling

```javascript
// Engine errors
engine.addEventListener('error', function(e) {
    Ti.API.error('Engine error: ' + e.message);
});

// Session errors
session.addEventListener('generateerror', function(e) {
    Ti.API.error('Generation error: ' + e.message);
});

// Downloader errors
downloader.addEventListener('downloaderror', function(e) {
    Ti.API.error('Download error: ' + e.message);
});
```

---

## Known Limitations

- **arm64 only on iOS**: x86_64 simulator is not supported.
- **Model size**: Models can be 1–20 GB — ensure sufficient storage.
- **Memory usage**: Loaded models require ~2–4x their file size in RAM.
- **No background mode**: LLM inference only runs in the foreground.
- **XNNPack cache warning on Android**: A non-fatal warning about weight cache persistence may appear. This does not affect inference quality, only cold-start cache performance.

---

## Platform Differences

### Model Paths

On Android, Titanium `appdata://` and `appdata-private://` URLs are automatically resolved to filesystem paths. You can use either format:

```javascript
// Both work on Android:
litertlm.createEngine({ modelPath: Ti.Filesystem.applicationDataDirectory + 'models/gemma.gguf' });
litertlm.createEngine({ modelPath: '/data/data/com.app/files/models/gemma.gguf' });
```

On iOS, use standard file paths or Titanium file URLs.

### Session API

The Session API (`generate`, `generateStream`, `collectStream`) is available on iOS. On Android, the Conversation API (`send`, `sendStream`) is the primary interface.

### Tool Execution

On Android, tool execution callbacks are invoked on the UI thread with a 30-second timeout. Long-running tool callbacks may time out.

---

## License

Apache License 2.0

---

## Author

mbender74 – [marc_bender@icloud.com](mailto:marc_bender@icloud.com)