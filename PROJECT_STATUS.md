# TitaniumLiteRTLM – Project Status & Architecture

## Project Overview

- **Module ID:** `de.marcbender.litertlm`
- **Version:** 1.0.0
- **Goal:** Titanium module wrapping Google LiteRT-LM SDK for on-device LLM inference on iOS and Android
- **Test App:** `/Users/marcbender/example/testApp`

## Build & Install

### iOS

```bash
# Build module
cd /Users/marcbender/TitaniumLiteRTLM/ios && ti build -p ios --build-only

# Install in test app
cd /Users/marcbender/example/testApp && rm -rf modules/iphone/de.marcbender.litertlm && \
  unzip -o /Users/marcbender/TitaniumLiteRTLM/ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip -d modules/iphone/
```

### Android

```bash
# Build module
cd /Users/marcbender/TitaniumLiteRTLM/android && ti build -p android --build-only

# Install in test app
cd /Users/marcbender/example/testApp && rm -rf modules/android/de.marcbender.litertlm && \
  unzip -o /Users/marcbender/TitaniumLiteRTLM/android/dist/de.marcbender.litertlm-android-1.0.0.zip -d modules/android/
```

## Debugging

### iOS

```bash
# Module logs in separate terminal (before app start)
log stream --predicate 'message contains "[DEBUG]"'
```

### Android

```bash
# Module logs via logcat
adb logcat -s LiteRTLMEngineProxy LiteRTLMConversationProxy LiteRTLMTool TitaniumLiteRTLMModule
```

## Architecture

### iOS File Structure

```
ios/Classes/
├── DeMarcbenderLitertlmModule.swift          # Main module (TiModule)
├── LiteRTLMModelDownloaderProxy.swift        # Downloader proxy (TiProxy) – no external import
├── LiteRTLMEngineProxy.swift                 # Engine proxy
├── LiteRTLMConversationProxy.swift           # Conversation proxy
├── LiteRTLMEngineConfiguration.swift         # Engine config proxy
├── LiteRTLMConversationConfiguration.swift   # Conversation config proxy
├── LiteRTLMSessionProxy.swift                # Session proxy
├── LiteRTLMSessionConfiguration.swift         # Session config proxy
├── LiteRTLMSamplerConfiguration.swift         # Sampler config proxy
├── LiteRTLMContent.swift                     # Content proxy
├── LiteRTLMMessage.swift                     # Message proxy
├── LiteRTLMTool.swift                        # Tool proxy
├── LiteRTLMModelInfo.swift                   # Model info proxy
└── LiteRTLMDownloader/
    ├── ModelDownloader.swift                  # @Observable, URLSession-based downloads
    ├── ModelInfo.swift                        # Swift struct with model metadata
    └── DownloadState.swift                    # enum: idle, downloading, paused, completed, failed
```

### Android File Structure

```
android/src/de/marcbender/litertlm/
├── TitaniumLiteRTLMModule.kt                # Main module (KrollModule)
├── LiteRTLMEngineProxy.kt                   # Engine proxy
├── LiteRTLMConversationProxy.kt             # Conversation proxy
├── LiteRTLMEngineConfiguration.kt           # Engine config proxy
├── LiteRTLMConversationConfiguration.kt     # Conversation config proxy
├── LiteRTLMSessionProxy.kt                  # Session proxy
├── LiteRTLMSessionConfiguration.kt          # Session config proxy
├── LiteRTLMSamplerConfiguration.kt          # Sampler config proxy
├── LiteRTLMContent.kt                       # Content proxy
├── LiteRTLMMessage.kt                       # Message proxy
├── LiteRTLMTool.kt                           # Tool proxy (implements OpenApiTool)
├── LiteRTLMModelInfo.kt                     # Model info proxy
└── LiteRTLMModelDownloaderProxy.kt          # Model downloader proxy (HTTP-based)
```

### Key Patterns

#### iOS: TiProxy Init Pattern

**Wrong (crashes):**
```swift
override init() {
    _downloader = ModelDownloader()  // ❌ Swift metadata init crashes
    super.init()
}
```

**Correct (reference: ti.circularprogress):**
```swift
override init() {
    super.init()  // ✅ Call super first, no external Swift types
}

override public func _init(withProperties properties: [AnyHashable : Any]!) {
    super._init(withProperties: properties)
    // ✅ Extract properties from JS, no external types
}
```

#### iOS: Facade Pattern for External Swift Types

Proxy classes should not import `CLiteRTLM` or reference external Swift types in `@objc` method signatures. Instead, delegate all SDK work to the module:

```swift
// LiteRTLMModelDownloaderProxy.swift – no external import
@objc(LiteRTLMModelDownloaderProxy)
public class LiteRTLMModelDownloaderProxy: TiProxy {
    @objc public func download(_ modelInfo: Any?) {
        module().delegateDownload(with: modelInfo, proxy: self)
    }
}

// DeMarcbenderLitertlmModule.swift – CLiteRTLM imported, does the work
func delegateDownload(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) {
    let dl = downloader()  // ModelDownloader
    // ... download logic
}
```

#### Android: Kroll V8 Array Handling

Kroll V8 on Android passes JS arrays as `Object[]` (not `ArrayList`). All array parsing must handle both:

```kotlin
private fun parseToolsArray(value: Any?): List<LiteRTLMTool> {
    val items = when (value) {
        is ArrayList<*> -> value
        is Array<*> -> value.toList()   // ✅ Handle Kroll V8 Object[]
        else -> return emptyList()
    }
    return items.mapNotNull { item ->
        when (item) {
            is LiteRTLMTool -> item
            is HashMap<*, *> -> {          // ✅ Handle plain JS objects
                val tool = LiteRTLMTool()
                tool.handleCreationDict(KrollDict(item as HashMap<String, Any>))
                tool
            }
            else -> null
        }
    }
}
```

#### Android: Titanium URL Resolution

Titanium `appdata://` and `appdata-private://` URLs must be resolved to real filesystem paths:

```kotlin
private fun resolveTiPath(path: String): String {
    return when {
        path.startsWith("appdata-private://") -> {
            val app = TiApplication.getInstance()
            File(app.filesDir, path.substringAfter("appdata-private://").removePrefix("/")).absolutePath
        }
        path.startsWith("appdata://") -> {
            val app = TiApplication.getInstance()
            File(app.filesDir, path.substringAfter("appdata://").removePrefix("/")).absolutePath
        }
        else -> path
    }
}
```

#### Android: Threading

1. All `fireEvent()` calls must run on the main thread via `Handler(Looper.getMainLooper())`
2. All SDK calls (initialize, sendMessage, etc.) must run on background threads
3. Tool execution (`LiteRTLMTool.execute()`) bridges to the UI thread via `CountDownLatch` with 30s timeout

## Current Status

### iOS

- **Working**: Engine loading, conversation creation, streaming, tool calling, model download, session API, multimodal input

### Android

- **Working**: Engine loading, conversation creation, streaming, tool calling, model download
- **Known issue**: XNNPack cache warning on startup (non-fatal, doesn't affect inference quality, only cold-start cache performance)

## Crash Fix History

### iOS

| Commit | Problem | Solution |
|--------|---------|----------|
| `4f1cb89` | `createDownloader` didn't return proxy to JS | Add `return proxy` |
| `b49af4f` | Swift objects released prematurely | Strong `_downloader: AnyObject?` property |
| `3845720` | ExampleProxy crashes on Swift metadata | Create instance in `startup()`, not lazy |
| `e99ee7f` | SIGSEGV in `swift_retain` on `createDownloader()` | Facade pattern: proxy without CLiteRTLM import, delegation to module |
| `0f71571` | Download, engine loading, JS bridge parameter passing | Fix download paths, engine init, proxy extraction |
| `b76f0d3` | Conversation streaming, event routing, proxy extraction, NULL config | Fix event routing, proxy extraction, NULL config handling |
| `d2da3c3` | Safe module-level closeConversation/unloadEngine | Add safe close/unload at module level |

### Android

| Commit | Problem | Solution |
|--------|---------|----------|
| `45deaf7` | Multiple runtime issues after initial Android build | Fix: Kroll V8 `Object[]` vs `ArrayList` handling, Titanium URL resolution for `appdata-private://`, correct arm64-v8a JNI `.so` binary, XNNPack cache directory creation with trailing `/` |

## Logging

### iOS
All debug logs use `NSLog("[DEBUG] ...")` and appear in:
- `log stream --predicate 'message contains "[DEBUG]"'` (Terminal)
- macOS Console.app
- Xcode Console (when launched via Xcode)

### Android
All debug logs use `Log.d(LCAT, ...)` with tag prefixes:
- `adb logcat -s LiteRTLMEngineProxy LiteRTLMConversationProxy LiteRTLMTool TitaniumLiteRTLMModule`
- Android Studio Logcat