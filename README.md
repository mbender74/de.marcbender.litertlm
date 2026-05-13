# TitaniumLiteRTLM – On-Device LLM Inference for Titanium

> **LiteRTLM** is a Titanium module that wraps the full [Google LiteRT-LM SDK](https://github.com/google/litert) for both iOS and Android. It enables running Large Language Models (LLMs) directly on-device — no network connection, no cloud dependencies, full privacy and low latency.

[![Platform](https://img.shields.io/badge/platform-iOS%20%26%20Android-blue.svg)](https://github.com/marcbender/TitaniumLiteRTLM)
[![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)](https://swift.org/)
[![Kotlin](https://img.shields.io/badge/kotlin-1.9-purple.svg)](https://kotlinlang.org/)
[![Titanium](https://img.shields.io/badge/titanium-13.x-brightgreen.svg)](https://ti.appcelerator.com/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

---

## Table of Contents

- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Configuration](#configuration)
  - [tiapp.xml](#tiappxml)
  - [iOS: info.plist](#ios-infoplist)
  - [Android: AndroidManifest.xml](#android-androidmanifestxml)
- [API Reference](#api-reference)
  - [Main Module (de.marcbender.litertlm)](#main-module-demarcbenderlitertlm)
  - [LiteRTLMEngine](#litemrtlmengine)
  - [LiteRTLMEngineConfiguration](#litemrtlmengineconfiguration)
  - [LiteRTLMSession](#litertlmsession)
  - [LiteRTLMSessionConfiguration](#litertlmsessionconfiguration)
  - [LiteRTLMConversation](#litemrtlmconversation)
  - [LiteRTLMConversationConfiguration](#litemrtlmconversationconfiguration)
  - [LiteRTLMSamplerConfiguration](#litertlmsamplerconfiguration)
  - [LiteRTLMContent](#litemrtlmcontent)
  - [LiteRTLMMessage](#litemrtlmmessage)
  - [LiteRTLMTool](#litemrtlmtool)
  - [LiteRTLMModelInfo](#litemrtlmmodelinfo)
  - [LiteRTLMModelDownloader](#litemrtlmmodeldownloader)
- [Full Example](#full-example)
- [Streaming API](#streaming-api)
- [Tool Calling / Function Calling](#tool-calling--function-calling)
- [Multimodal Input (Vision, Audio)](#multimodal-input-vision-audio)
- [Error Handling](#error-handling)
- [Model Downloads](#model-downloads)
- [Performance Tips](#performance-tips)
- [Debugging](#debugging)
- [Known Limitations](#known-limitations)
- [Platform Differences](#platform-differences)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

- **Full API coverage**: Engine, Sessions, Conversations, Streaming, Tool Calling, Multimodal Input
- **Cross-platform**: iOS and Android with a unified JavaScript API
- **On-device inference**: No internet connection required, all data stays on the device
- **Stream processing**: Real-time token-by-token output
- **Tool Calling**: LLMs can call functions in your app
- **Multimodal input**: Text, images (vision) and audio
- **Model Downloader**: Built-in model download and management
- **Configurable samplers**: Greedy, Balanced, Creative, or custom
- **Benchmarking**: Model inference performance measurement
- **Memory-optimized**: Runtime model load/unload

---

## System Requirements

| Component | iOS Minimum | Android Minimum | Recommended |
|-----------|------------|-----------------|-------------|
| **OS** | iOS 17.0 | Android 8.0 (API 26) | iOS 17.6+ / Android 10+ |
| **Titanium SDK** | 13.2.0.GA | 13.2.0.GA | 13.3.x or newer |
| **Xcode** | 15.0 | N/A | 16.x or newer |
| **Hardware** | A12 Bionic | ARM64 device | A15+ or M-Series / Snapdragon 8+ |

> **Note**: On iOS, only **arm64** architecture is supported (physical devices and Apple Silicon simulators). On Android, **arm64-v8a** and **x86_64** architectures are supported.

---

## Installation

### Option 1: Local ZIP (Recommended)

#### iOS

1. Build the module:
   ```bash
   cd TitaniumLiteRTLM/ios
   ti build -p ios --build-only
   ```

2. The ZIP is generated in the `dist` directory:
   ```
   ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip
   ```

3. Copy the ZIP to your project:
   ```bash
   cp ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip /path/to/your-project/modules/
   ```

#### Android

1. Build the module:
   ```bash
   cd TitaniumLiteRTLM/android
   ti build -p android --build-only
   ```

2. The ZIP is generated in the `dist` directory:
   ```
   android/dist/de.marcbender.litertlm-android-1.0.0.zip
   ```

3. Copy the ZIP to your project:
   ```bash
   cp android/dist/de.marcbender.litertlm-android-1.0.0.zip /path/to/your-project/modules/
   ```

### Option 2: Global installation

Copy the ZIP to the global module directory:

```bash
# iOS
cp ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip \
   ~/Library/Application Support/Titanium/modules/de.marcbender.litertlm/

# Android
cp android/dist/de.marcbender.litertlm-android-1.0.0.zip \
   ~/Library/Application Support/Titanium/modules/de.marcbender.litertlm/
```

---

## Configuration

### tiapp.xml

Add the module for both platforms:

```xml
<modules>
    <module version="1.0.0" platform="ios">de.marcbender.litertlm</module>
    <module version="1.0.0" platform="android">de.marcbender.litertlm</module>
</modules>
```

### iOS: info.plist

For camera/photo access with vision features, add:

```xml
<key>NSCameraUsageDescription</key>
<string>Required for image recognition in conversations</string>

<key>NSMicrophoneUsageDescription</key>
<string>Required for audio input in conversations</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Required for selecting images from the photo library</string>
```

### Android: AndroidManifest.xml

The module automatically adds the `INTERNET` permission for model downloads. If you need camera/microphone access:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## API Reference

### Main Module (`de.marcbender.litertlm`)

#### `getVersion()` → `String`

Returns the module version.

```javascript
var version = litertlm.getVersion();
console.log('Module version: ' + version);
```

#### `createEngine(args)` → `undefined`

Loads a model and creates a `LiteRTLMEngine`.

**Parameters:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `modelPath` | `String` | required | Path to model file or directory |
| `backend` | `String` | `'cpu'` | `'cpu'` or `'gpu'` |
| `maxTokens` | `Int32` | `0` (unlimited) | Maximum number of generated tokens |
| `cacheDir` | `String` | `null` | Cache directory for the model |
| `benchmarkEnabled` | `Boolean` | `false` | Enable benchmarking |
| `logLevel` | `String` | `'warning'` | `'error'`, `'warning'`, `'info'`, `'fatal'`, `'silent'` |

**Events:**

- `enginecreated` – Fired when the engine is loaded successfully
  - `engine`: `LiteRTLMEngine` proxy object

**Example:**

```javascript
litertlm.createEngine({
    modelPath: '/path/to/gemma-2b-it',
    backend: 'gpu',
    maxTokens: 1024,
    benchmarkEnabled: true
});

litertlm.addEventListener('enginecreated', function(e) {
    var engine = e.engine;
    console.log('Engine status: ' + engine.status);
    console.log('Is ready: ' + engine.isReady);
});
```

#### `createEngineWithConfig(config)` → `undefined`

Creates an engine with a `LiteRTLMEngineConfiguration` object.

```javascript
var config = litertlm.createEngineConfigProxy({
    modelPath: '/path/to/model',
    backend: 'gpu',
    maxTokens: 1024,
    cacheDir: '/path/to/cache'
});

litertlm.createEngineWithConfig(config);
```

#### `createEngineConfigProxy(args)` → `LiteRTLMEngineConfiguration`

Creates an engine configuration.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `modelPath` | `String` | Path to the model |
| `backend` | `String` | `'cpu'` or `'gpu'` |
| `maxTokens` | `Int32` | Maximum token count |
| `cacheDir` | `String` | Cache directory |
| `benchmarkEnabled` | `Boolean` | Enable benchmarking |
| `logLevel` | `String` | Log level |
| `visionBackend` | `String` | Backend for vision/images |
| `audioBackend` | `String` | Backend for audio |

#### `createSessionConfigProxy(args)` → `LiteRTLMSessionConfiguration`

Creates a session configuration.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `maxOutputTokens` | `Int32` | Maximum output tokens |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `createConversationConfigProxy(args)` → `LiteRTLMConversationConfiguration`

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

#### `createSamplerConfigProxy(args)` → `LiteRTLMSamplerConfiguration`

Creates a sampler configuration for fine-grained control of text generation.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `temperature` | `Double` | 0.0–2.0 (low = deterministic, high = creative) |
| `topK` | `Int32` | Consider only the top-K tokens |
| `topP` | `Double` | Nucleus sampling (0.0–1.0) |
| `seed` | `Int32` | Random seed for reproducibility |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `createContentProxy(args)` → `LiteRTLMContent`

Creates a content object for text, images, or audio.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Text content (for type='text') |
| `imageData` | `Ti.Blob` | Image data (for type='image') |
| `audioData` | `Ti.Blob` | Audio data (for type='audio') |
| `audioFormat` | `String` | Audio format (e.g. `'wav'`, `'mp3'`) |
| `maxDimension` | `Int` | Maximum image dimension |

#### `createMessageProxy(args)` → `LiteRTLMMessage`

Creates a message (payload) for a conversation.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | List of `LiteRTLMContent` objects |

**Helper functions:**

```javascript
// User message
var userMsg = litertlm.createMessageProxy({
    role: 'user',
    contents: [content]
});

// System prompt
var systemMsg = litertlm.createMessageProxy({
    role: 'system',
    contents: [textContent]
});
```

#### `createToolProxy(args)` → `LiteRTLMTool`

Creates a tool (function) for tool calling.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Function name |
| `description` | `String` | Description of what the function does |
| `parameters` | `Array` | Parameter definitions |

**Parameter schema:**

Each parameter is an object with:

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Parameter name |
| `type` | `String` | `'string'`, `'number'`, `'boolean'`, `'object'`, `'array'` |
| `description` | `String` | Parameter description |
| `required` | `Boolean` | Whether the parameter is required |

**Example:**

```javascript
var tool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Gets the current weather for a location',
    parameters: [{
        name: 'location',
        type: 'string',
        description: 'City or zip code',
        required: true
    }]
});

// Callback for tool execution
tool.executeCallback = function(args, callback) {
    var location = args.location;
    // Call weather API...
    var result = { temperature: 22, condition: 'sunny' };
    callback(result);
};
```

#### `createDownloader(args)` → `LiteRTLMModelDownloader`

Creates a model downloader.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `modelsDirectory` | `String` | Directory for storing models |

#### `createModelInfo(args)` → `LiteRTLMModelInfo`

Creates a model info object for downloading.

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `name` | `String` | Internal model name |
| `displayName` | `String` | Display name |
| `url` | `String` | Download URL |
| `expectedSize` | `Int64` | Expected file size in bytes |
| `fileName` | `String` | File name after download |

#### `closeConversation(conv)` → `undefined`

Safely closes a conversation from the module level.

#### `unloadEngine(engine)` → `undefined`

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

##### `load()` → `undefined`

Loads the model into memory.

```javascript
engine.load();
```

##### `unload()` → `undefined`

Unloads the model from memory.

```javascript
engine.unload();
```

##### `createSession(config?)` → `undefined`

Creates a new session.

**Parameters:**

- `config` (`LiteRTLMSessionConfiguration`, optional)

**Events:**

- `sessioncreated` – Session created successfully
  - `session`: `LiteRTLMSession` proxy object

```javascript
engine.createSession();
```

##### `createSessionWithConfig(config)` → `undefined`

Creates a session with configuration.

```javascript
var config = litertlm.createSessionConfigProxy({
    maxOutputTokens: 512,
    samplerType: 'balanced'
});
engine.createSessionWithConfig(config);
```

##### `createConversation(config?)` → `undefined`

Creates a new conversation.

**Events:**

- `conversationcreated` – Conversation created successfully
  - `conversation`: `LiteRTLMConversation` proxy object

```javascript
engine.createConversation();
```

##### `createConversationWithConfig(config)` → `undefined`

Creates a conversation with configuration.

```javascript
var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'You are a helpful assistant.',
    maxOutputTokens: 1024,
    toolExecutionMode: 'auto'
});
engine.createConversationWithConfig(config);
```

---

### LiteRTLMEngineConfiguration

Configuration for the engine.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `modelPath` | `String` | Path to the model |
| `primaryBackend` | `String` | `'cpu'` or `'gpu'` |
| `visionBackend` | `String` | Vision backend |
| `audioBackend` | `String` | Audio backend |
| `maxTokens` | `Int32` | Maximum tokens |
| `cacheDir` | `String` | Cache directory |
| `isBenchmarkEnabled` | `Boolean` | Benchmarking enabled |
| `logLevel` | `String` | Log level |

---

### LiteRTLMSession

Represents a single inference session (single request).

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isActive` | `Boolean` | Whether the session is active |

#### Methods

##### `generate(text, config?)` → `undefined`

Generates text in response to an input.

```javascript
session.generate('What is AI?');
```

**Events:**

- `generateready` – Generation completed
  - `result`: `String` – The generated response
  - `benchmarkInfo`: `Object` (optional) – Performance information

- `generateerror` – Error during generation
  - `message`: `String` – Error message

##### `generateMultimodal(contents, config?)` → `undefined`

Generates a response to multimodal input (text + images + audio).

```javascript
var textContent = litertlm.createContentProxy({ type: 'text', text: 'What do you see in the image?' });
var imageContent = litertlm.createContentProxy({
    type: 'image',
    imageData: imageBlob,
    maxDimension: 1024
});

session.generateMultimodal([textContent, imageContent]);
```

##### `generateStream(text, config?)` → `undefined`

Starts a streaming generation process.

```javascript
session.generateStream('Tell me a story.');
```

**Events:**

- `streamstart` – Streaming started
  - `sessionId`: `String` – Session ID

- `token` – New token received
  - `token`: `String` – The received token

- `streamcomplete` – Streaming completed
  - `result`: `String` – Full response
  - `benchmarkInfo`: `Object` (optional)

- `streamerror` – Error during streaming
  - `message`: `String` – Error message

- `streamend` – Streaming ended

##### `collectStream(text, config?)` → `undefined`

Starts streaming and collects all tokens into a result.

```javascript
session.collectStream('Explain quantum physics simply.');
```

##### `close()` → `undefined`

Closes the session.

```javascript
session.close();
```

##### `benchmarkInfo` → `Object`

Returns performance information.

```javascript
var info = session.benchmarkInfo;
console.log('Tokens/s: ' + info.tokensPerSecond);
console.log('Time: ' + info.latencyMs + 'ms');
```

---

### LiteRTLMSessionConfiguration

Configuration for a session.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `maxOutputTokens` | `Int32` | Maximum output tokens |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |
| `temperature` | `Float` | Temperature (0.0–2.0) |
| `topK` | `Int32` | Top-K value |
| `topP` | `Float` | Top-P value (nucleus sampling) |
| `seed` | `Int32` | Random seed |

---

### LiteRTLMConversation

Represents a multi-turn conversation with history.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isActive` | `Boolean` | Whether the conversation is active |
| `history` | `Array` | List of `LiteRTLMMessage` objects |

#### Methods

##### `send(message, config?)` → `undefined`

Sends a message and receives a response.

```javascript
var message = litertlm.createMessageProxy({
    role: 'user',
    contents: [textContent]
});

conversation.send(message);
```

**Events:**

- `messagecomplete` – Response complete
  - `message`: `LiteRTLMMessage` – Model's response
  - `benchmarkInfo`: `Object` (optional)

- `messageerror` – Error sending message
  - `message`: `String` – Error message

##### `sendMultimodal(message, config?)` → `undefined`

Sends a multimodal message.

```javascript
var message = litertlm.createMessageProxy({
    role: 'user',
    contents: [textContent, imageContent]
});

conversation.sendMultimodal(message);
```

##### `sendStream(message, config?)` → `undefined`

Sends a message with streaming response.

**Events:**

- `streamstart` – Streaming started
- `token` – New token
- `streamcomplete` – Streaming completed
- `streamerror` – Error
- `streamend` – Streaming ended

##### `collectStream(message, config?)` → `undefined`

Collects all tokens from a streaming response.

##### `cancel()` → `undefined`

Cancels the current request.

```javascript
conversation.cancel();
```

##### `close()` → `undefined`

Closes the conversation.

```javascript
conversation.close();
```

##### `getHistory()` → `Array`

Returns the conversation history.

```javascript
var history = conversation.getHistory();
console.log('Messages in history: ' + history.length);
```

---

### LiteRTLMConversationConfiguration

Configuration for a conversation.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `maxOutputTokens` | `Int32` | Maximum output tokens |
| `samplerType` | `String` | Sampler type |
| `tools` | `Array` | List of tools |
| `toolExecutionMode` | `String` | `'auto'`, `'required'`, `'disabled'` |
| `maxImageDimension` | `Int` | Maximum image size |
| `systemPrompt` | `String` | System prompt |

---

### LiteRTLMSamplerConfiguration

Fine-grained sampler configuration.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `temperature` | `Float` | Temperature (0.0–2.0) |
| `topK` | `Int32` | Top-K value |
| `topP` | `Float` | Top-P value |
| `seed` | `Int32` | Random seed |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### Static Methods

```javascript
// Greedy (deterministic, lowest temperature)
var greedyConfig = litertlm.createSamplerConfigProxy();
greedyConfig.temperature = 0.0;
greedyConfig.topK = 1;

// Balanced (default)
var balancedConfig = litertlm.createSamplerConfigProxy();
balancedConfig.temperature = 0.7;

// Creative (highest temperature)
var creativeConfig = litertlm.createSamplerConfigProxy();
creativeConfig.temperature = 1.5;
creativeConfig.topP = 0.95;
```

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

**Helper functions:**

```javascript
// Text content
var textContent = litertlm.createContentProxy({
    type: 'text',
    text: 'Hello world!'
});

// Image content
var imageContent = litertlm.createContentProxy({
    type: 'image',
    imageData: imageBlob,
    maxDimension: 1024
});

// Audio content
var audioContent = litertlm.createContentProxy({
    type: 'audio',
    audioData: audioBlob,
    audioFormat: 'wav'
});
```

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

---

### LiteRTLMModelInfo

Information about a model.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Model name |
| `displayName` | `String` | Display name |
| `url` | `String` | Download URL |
| `expectedSize` | `Int64` | Expected size |
| `fileName` | `String` | File name |
| `status` | `String` | `'unknown'`, `'available'`, `'downloading'`, `'downloaded'`, `'error'` |

#### Static Models

```javascript
var gemma2b = litertlm.createModelInfo({
    name: 'gemma-2b-it',
    displayName: 'Gemma 2B It',
    url: 'https://...',
    expectedSize: 5000000000,
    fileName: 'gemma-2b-it'
});
```

---

### LiteRTLMModelDownloader

Model downloader for downloading and managing models.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `modelsDirectory` | `String` | Models directory |

#### Methods

##### `download(modelInfo)` → `undefined`

Starts downloading a model.

```javascript
downloader.download(modelInfo);
```

**Events:**

- `downloadstart` – Download started
- `downloadprogress` – Download progress
  - `progress`: `Float` (0.0–1.0)
  - `bytesDownloaded`: `Int64`
  - `totalBytes`: `Int64`
- `downloadcomplete` – Download completed
  - `modelInfo`: `LiteRTLMModelInfo`
- `downloaderror` – Download error
  - `message`: `String`

##### `downloadFrom(url, fileName?, expectedSize?)` → `undefined`

Downloads a model from a URL.

```javascript
downloader.downloadFrom(
    'https://example.com/model.gguf',
    'my-model.gguf',
    5000000000
);
```

##### `pause()` → `undefined`

Pauses the current download.

```javascript
downloader.pause();
```

##### `cancel()` → `undefined`

Cancels the download.

```javascript
downloader.cancel();
```

##### `isDownloaded(modelInfo)` → `Boolean`

Checks if a model is downloaded.

```javascript
var exists = downloader.isDownloaded(modelInfo);
if (exists) {
    console.log('Model already downloaded');
} else {
    downloader.download(modelInfo);
}
```

##### `modelPath(modelInfo)` → `String`

Returns the path to the model.

```javascript
var path = downloader.modelPath(modelInfo);
console.log('Model path: ' + path);
```

##### `deleteModel(modelInfo)` → `undefined`

Deletes a downloaded model.

```javascript
downloader.deleteModel(modelInfo);
```

##### `deleteModelByFileName(fileName)` → `undefined`

Deletes a model by file name.

```javascript
downloader.deleteModelByFileName('my-model.gguf');
```

---

## Full Example

A complete example is available in the `example/app.js` directory. It demonstrates:

- Model download and management
- Engine initialization
- Simple text generation
- Streaming output
- Conversation with history
- Tool calling
- Multimodal input (vision)
- Error handling

---

## Streaming API

Streaming enables real-time token-by-token output:

```javascript
// Simple streaming
session.generateStream('Tell me a story about a robot.');

session.addEventListener('streamstart', function(e) {
    console.log('Streaming started');
    outputText = '';
});

session.addEventListener('token', function(e) {
    // Each token is received individually
    outputText += e.token;
    label.text = outputText; // Live UI update
});

session.addEventListener('streamcomplete', function(e) {
    console.log('Streaming completed');
    console.log('Full response: ' + e.result);
});

session.addEventListener('streamend', function(e) {
    console.log('Streaming ended');
});
```

---

## Tool Calling / Function Calling

LLMs can call functions in your app:

```javascript
// 1. Define a tool
var weatherTool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Gets the current weather for a location',
    parameters: [{
        name: 'location',
        type: 'string',
        description: 'City or zip code',
        required: true
    }]
});

// 2. Set the callback
weatherTool.executeCallback = function(args, callback) {
    Ti.API.info('Tool called with args: ' + JSON.stringify(args));

    // Call external API
    var weatherData = getWeatherFromAPI(args.location);

    // Return the result
    callback({
        temperature: weatherData.temp,
        condition: weatherData.condition,
        humidity: weatherData.humidity
    });
};

// 3. Pass tool to conversation
var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'You are a helpful weather assistant.',
    tools: [weatherTool],
    toolExecutionMode: 'auto'
});

engine.createConversationWithConfig(config);

// 4. Process model response
conversation.addEventListener('messagecomplete', function(e) {
    var message = e.message;
    if (message.role === 'model') {
        // Model may have called tools
        console.log('Model response: ' + message.contents[0].text);
    }
});
```

---

## Multimodal Input (Vision, Audio)

### Image Recognition (Vision)

```javascript
// Select image from photo library
var imageDialog = Ti.UI.createOptionDialog({
    title: 'Select Image',
    options: ['Camera', 'Photo Library', 'Cancel'],
    cancel: 2,
    destructive: 2
});

imageDialog.show();
imageDialog.addEventListener('click', function(e) {
    if (e.index === 0) {
        // Open camera
        Ti.Media.openCamera({
            success: function(event) {
                var imageContent = litertlm.createContentProxy({
                    type: 'image',
                    imageData: event.media,
                    maxDimension: 1024
                });

                var textContent = litertlm.createContentProxy({
                    type: 'text',
                    text: 'What do you see in this image?'
                });

                session.generateMultimodal([textContent, imageContent]);
            },
            cancel: function() {},
            error: function(error) {
                alert('Camera error: ' + error);
            }
        });
    }
});
```

### Audio Input

```javascript
var audioContent = litertlm.createContentProxy({
    type: 'audio',
    audioData: audioBlob,
    audioFormat: 'wav'
});

session.generateMultimodal([audioContent]);
```

---

## Error Handling

All asynchronous operations can trigger errors. Always use error listeners:

```javascript
// Engine errors
engine.addEventListener('error', function(e) {
    Ti.API.error('Engine error: ' + e.message);
    alert('Error: ' + e.message);
});

// Session errors
session.addEventListener('generateerror', function(e) {
    Ti.API.error('Generation error: ' + e.message);
});

// Conversation errors
conversation.addEventListener('messageerror', function(e) {
    Ti.API.error('Message error: ' + e.message);
});

// Streaming errors
session.addEventListener('streamerror', function(e) {
    Ti.API.error('Streaming error: ' + e.message);
});

// Downloader errors
downloader.addEventListener('downloaderror', function(e) {
    Ti.API.error('Download error: ' + e.message);
});
```

---

## Model Downloads

The module supports downloading models via HTTP/HTTPS:

```javascript
// Create downloader
var downloader = litertlm.createDownloader({
    modelsDirectory: Ti.Filesystem.applicationDataDirectory + 'models/'
});

// Create model info
var modelInfo = litertlm.createModelInfo({
    name: 'gemma-2b-it',
    displayName: 'Gemma 2B It',
    url: 'https://storage.googleapis.com/gemma-2b-it/gemma-2b-it.gguf',
    expectedSize: 5000000000, // 5 GB
    fileName: 'gemma-2b-it.gguf'
});

// Show download progress
downloader.addEventListener('downloadprogress', function(e) {
    progressIndicator.value = e.progress * 100;
    label.text = 'Download: ' + Math.round(e.progress * 100) + '%';
});

// Start download
downloader.download(modelInfo);
```

---

## Performance Tips

1. **Use GPU backend**: When available, the GPU backend is significantly faster than CPU.
   ```javascript
   litertlm.createEngineWithConfig({
       backend: 'gpu'
   });
   ```

2. **Model load/unload**: Unload models when not needed to free memory.
   ```javascript
   engine.unload(); // Free memory
   // ... later
   engine.load();   // Reload
   ```

3. **Cache directory**: Use a cache directory for faster load times.
   ```javascript
   litertlm.createEngineWithConfig({
       cacheDir: Ti.Filesystem.applicationCachesDirectory
   });
   ```

4. **Maximum tokens**: Set `maxTokens` to limit memory usage.

5. **Batch processing**: For multiple requests, use sessions instead of creating new conversations.

---

## Debugging

Enable debug mode for detailed logging:

```javascript
// In tiapp.xml
<property name="ti.logging" type="bool">true</property>

// Or in code
Ti.API.info = function(msg) {
    console.log('[LITERTLM] ' + msg);
};
```

Check engine status:

```javascript
console.log('Status: ' + engine.status);
console.log('Is ready: ' + engine.isReady);
console.log('Last error: ' + engine.lastError);
```

---

## Known Limitations

- **arm64 only on iOS**: x86_64 simulator is not supported.
- **Model size**: Models can be 1–20 GB in size — ensure sufficient storage space.
- **Memory usage**: Loaded models require ~2–4x their file size in RAM.
- **No background mode**: LLM inference only runs in the foreground.
- **XNNPack cache warning on Android**: A non-fatal warning about weight cache persistence may appear on Android. This does not affect inference quality, only the cold-start performance of the cache.

---

## Platform Differences

The module provides a unified JavaScript API across iOS and Android, but there are a few platform-specific differences:

### Model Paths

On Android, Titanium `appdata://` and `appdata-private://` URLs are automatically resolved to filesystem paths. You can use either format:

```javascript
// Both work on Android:
litertlm.createEngine({ modelPath: Ti.Filesystem.applicationDataDirectory + 'models/gemma.gguf' });
litertlm.createEngine({ modelPath: '/data/data/com.app/files/models/gemma.gguf' });
```

On iOS, use standard file paths or Titanium file URLs.

### Tool Execution

On Android, tool execution callbacks are invoked on the UI thread with a 30-second timeout. Long-running tool callbacks may time out.

### Session API

The Session API (`generate`, `generateStream`, `collectStream`) is available on iOS. On Android, the Conversation API (`send`, `sendStream`) is the primary interface.

---

## Roadmap

- [x] **iOS support**
- [x] **Android support**
- [ ] **Real-time speech recognition (STT)**
- [ ] **Text-to-Speech (TTS)**
- [ ] **RAG (Retrieval-Augmented Generation)**
- [ ] **Multi-model support**
- [ ] **Web-View integration**
- [ ] **CI/CD pipeline**
- [ ] **Comprehensive tests**

---

## License

This project is licensed under the [Apache License 2.0](LICENSE).

```
Copyright 2026 mbender74

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## Author

**mbender74**

- GitHub: [@marcbender](https://github.com/marcbender)
- Email: [marc_bender@icloud.com](mailto:marc_bender@icloud.com)

---

## Contributing

Contributions are welcome! Please create an issue or pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a pull request

---

## Support

For questions or issues:

- [GitHub Issues](https://github.com/marcbender/TitaniumLiteRTLM/issues)
- [GitHub Discussions](https://github.com/marcbender/TitaniumLiteRTLM/discussions)