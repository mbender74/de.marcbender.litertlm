# TitaniumLiteRTLM – On-Device LLM Inference for Titanium iOS

> **LiteRTLM** ist ein Titanium-Modul, das das vollständige [Google LiteRTLM-Swift-SDK](https://github.com/google/litert) als iOS-Modul verfügbar macht. Es ermöglicht die Ausführung von Large Language Models (LLMs) direkt auf dem Gerät – ohne Netzwerkverbindung, ohne Cloud-Abhängigkeiten, mit Datenschutz und niedriger Latenz.

[![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)](https://swift.org/)
[![Titanium](https://img.shields.io/badge/titanium-13.x-brightgreen.svg)](https://ti.appcelerator.com/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

---

## 📋 Inhaltsverzeichnis

- [Features](#-features)
- [Systemanforderungen](#-systemanforderungen)
- [Installation](#-installation)
- [Konfiguration](#-konfiguration)
  - [tiapp.xml](#tiappxml)
  - [info.plist](#infoplist)
- [API-Referenz](#-api-referenz)
  - [Hauptmodul (de.marcbender.litertlm)](#hauptmodul-demarcbenderlitertlm)
  - [LiteRTLMEngine](#litemrtlmengine)
  - [LiteRTLMEngineConfiguration](#litemrtlmengineconfiguration)
  - [LiteRTLMSession](#litemrtlmSession)
  - [LiteRTLMSessionConfiguration](#litemrtlmSessionconfiguration)
  - [LiteRTLMConversation](#litemrtlmConversation)
  - [LiteRTLMConversationConfiguration](#litemrtlmConversationconfiguration)
  - [LiteRTLMSamplerConfiguration](#litemrtlmSamplerConfiguration)
  - [LiteRTLMContent](#litemrtlmContent)
  - [LiteRTLMMessage](#litemrtlmMessage)
  - [LiteRTLMTool](#litemrtlmTool)
  - [LiteRTLMModelInfo](#litemrtlmModelInfo)
  - [LiteRTLMModelDownloader](#litemrtlmModelDownloader)
- [Vollständiges Beispiel](#-vollständiges-beispiel)
- [Streaming-API](#-streaming-api)
- [Tool Calling / Function Calling](#-tool-calling--function-calling)
- [Mehrmodale Eingabe (Vision, Audio)](#-mehrmodale-eingabe-vision-audio)
- [Fehlerbehandlung](#-fehlerbehandlung)
- [Modell-Downloads](#-modell-downloads)
- [Performance-Tipps](#-performance-tipps)
- [Debugging](#-debugging)
- [Bekannte Einschränkungen](#-bekannte-einschränkungen)
- [Roadmap](#-roadmap)
- [Lizenz](#-lizenz)

---

## ✨ Features

- **Vollständige API-Abdeckung**: Engine, Sessions, Conversations, Streaming, Tool Calling, mehrmodale Eingabe
- **On-Device-Inferenz**: Keine Internetverbindung erforderlich, alle Daten bleiben auf dem Gerät
- **Stream-Verarbeitung**: Token-für-Token-Ausgabe in Echtzeit
- **Tool Calling**: LLMs können Funktionen Ihrer App aufrufen
- **Mehrmodale Eingabe**: Text, Bilder (Vision) und Audio
- **Modell-Downloader**: Integriertes Herunterladen und Verwalten von Modellen
- **Konfigurierbare Sampler**: Greedy, Balanced, Creative oder benutzerdefiniert
- **Benchmarking**: Leistungsmessung der Modell-Inferenz
- **Speicheroptimiert**: Modell-Last/Entlastung zur Laufzeit

---

## 📱 Systemanforderungen

| Komponente | Mindestversion | Empfohlen |
|------------|----------------|-----------|
| **iOS** | 17.0 | 17.6+ |
| **Titanium SDK** | 13.2.0.GA | 13.3.x oder neuer |
| **Xcode** | 15.0 | 16.x oder neuer |
| **Swift** | 5.9 | 5.10+ |
| **Hardware** | A12 Bionic (iOS 17 Gerät) | A15+ oder M-Series Chip |

> **Hinweis**: Das Modul unterstützt ausschließlich **arm64**-Architektur (physische Geräte und Apple Silicon Simulatoren). x86_64-Simulator wird nicht unterstützt.

---

## 📦 Installation

### Option 1: Lokales ZIP (Empfohlen)

1. Bauen Sie das Modul:
   ```bash
   cd TitaniumLiteRTLM/ios
   ti build -p ios --build-only
   ```

2. Das ZIP entsteht im `dist`-Verzeichnis:
   ```
   ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip
   ```

3. Kopieren Sie das ZIP in Ihr Projekt-Root oder in das Module-Verzeichnis:
   ```bash
   cp ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip /path/to/your-project/modules/
   ```

### Option 2: Globale Installation

Kopieren Sie das ZIP in den globalen Module-Ordner:

```bash
cp ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip \
   ~/Library/Application Support/Titanium/modules/de.marcbender.litertlm/
```

---

## ⚙️ Konfiguration

### tiapp.xml

Fügen Sie das Modul in Ihre `tiapp.xml` ein:

```xml
<modules>
    <module version="1.0.0" platform="ios">de.marcbender.litertlm</module>
</modules>
```

### info.plist

Für Kamera-/Foto-Zugriff bei Vision-Funktionen fügen Sie hinzu:

```xml
<key>NSCameraUsageDescription</key>
<string>Benötigt für die Bilderkennung in Conversations</string>

<key>NSMicrophoneUsageDescription</key>
<string>Benötigt für Audio-Eingabe in Conversations</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Benötigt für die Auswahl von Bildern aus der Fotomediathek</string>
```

---

## 📚 API-Referenz

### Hauptmodul (`de.marcbender.litertlm`)

#### `getVersion()` → `String`

Gibt die Modul-Version zurück.

```javascript
var version = litertlm.getVersion();
console.log('Module version: ' + version);
```

#### `createEngine(args)` → `undefined`

Lädt ein Modell und erstellt eine `LiteRTLMEngine`.

**Parameter:**

| Schlüssel | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `modelPath` | `String` | erforderlich | Pfad zur Modell-Datei oder -directory |
| `backend` | `String` | `'cpu'` | `'cpu'`, `'gpu'` |
| `maxTokens` | `Int32` | `0` (unbegrenzt) | Maximale Anzahl generierter Tokens |
| `cacheDir` | `String` | `null` | Cache-Verzeichnis für das Modell |
| `benchmarkEnabled` | `Boolean` | `false` | Leistungsmessung aktivieren |
| `logLevel` | `String` | `'warning'` | `'error'`, `'warning'`, `'info'`, `'fatal'`, `'silent'` |

**Ereignisse:**

- `enginecreated` – Wird ausgelöst, wenn die Engine erfolgreich geladen wurde
  - `engine`: `LiteRTLMEngine` Proxy-Objekt

**Beispiel:**

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

Erstellt eine Engine mit einem `LiteRTLMEngineConfiguration`-Objekt.

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

Erstellt eine Engine-Konfiguration.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `modelPath` | `String` | Pfad zum Modell |
| `backend` | `String` | `'cpu'` oder `'gpu'` |
| `maxTokens` | `Int32` | Maximale Token-Anzahl |
| `cacheDir` | `String` | Cache-Verzeichnis |
| `benchmarkEnabled` | `Boolean` | Benchmarking aktivieren |
| `logLevel` | `String` | Log-Stufe |
| `visionBackend` | `String` | Backend für Vision/ Bilder |
| `audioBackend` | `String` | Backend für Audio |

#### `createSessionConfigProxy(args)` → `LiteRTLMSessionConfiguration`

Erstellt eine Session-Konfiguration.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `maxOutputTokens` | `Int32` | Maximale Output-Token |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `createConversationConfigProxy(args)` → `LiteRTLMConversationConfiguration`

Erstellt eine Conversation-Konfiguration.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `maxOutputTokens` | `Int32` | Maximale Output-Token |
| `samplerType` | `String` | Sampler-Typ |
| `tools` | `Array` | Liste von `LiteRTLMTool`-Objekten |
| `toolExecutionMode` | `String` | `'auto'`, `'required'`, `'disabled'` |
| `maxImageDimension` | `Int` | Maximale Bildgröße in Pixel |
| `systemPrompt` | `String` | System-Prompt für die Conversation |

#### `createSamplerConfigProxy(args)` → `LiteRTLMSamplerConfiguration`

Erstellt eine Sampler-Konfiguration für feinkörnige Steuerung der Textgenerierung.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `temperature` | `Double` | 0.0–2.0 (niedrig = deterministisch, hoch = kreativ) |
| `topK` | `Int32` | Nur die Top-K Tokens berücksichtigen |
| `topP` | `Double` | Nukleare Abtastung (0.0–1.0) |
| `seed` | `Int32` | Zufalls-Seed für Reproduzierbarkeit |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `createContentProxy(args)` → `LiteRTLMContent`

Erstellt ein Content-Objekt für Text, Bilder oder Audio.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Textinhalt (für type='text') |
| `imageData` | `Ti.Blob` | Bilddaten (für type='image') |
| `audioData` | `Ti.Blob` | Audiodaten (für type='audio') |
| `audioFormat` | `String` | Audio-Format (z.B. `'wav'`, `'mp3'`) |
| `maxDimension` | `Int` | Maximale Bildabmessung |

#### `createMessageProxy(args)` → `LiteRTLMMessage`

Erstellt eine Message (Nutzlast) für eine Conversation.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | Liste von `LiteRTLMContent`-Objekten |

**Hilfsfunktionen:**

```javascript
// Benutzer-Nachricht
var userMsg = litertlm.createMessageProxy({
    role: 'user',
    contents: [content]
});

// Modell-Antwort (vom System gesetzt)
// role: 'model'

// System-Prompt
var systemMsg = litertlm.createMessageProxy({
    role: 'system',
    contents: [textContent]
});
```

#### `createToolProxy(args)` → `LiteRTLMTool`

Erstellt ein Tool (Function) für das Tool Calling.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Name der Funktion |
| `description` | `String` | Beschreibung, was die Funktion tut |
| `parameters` | `Array` | Parameter-Definitionen |

**Parameter-Schema:**

Jeder Parameter ist ein Objekt mit:

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Name des Parameters |
| `type` | `String` | `'string'`, `'number'`, `'boolean'`, `'object'`, `'array'` |
| `description` | `String` | Beschreibung des Parameters |
| `required` | `Boolean` | Ob der Parameter erforderlich ist |

**Beispiel:**

```javascript
var tool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Holt das aktuelle Wetter für einen Ort',
    parameters: [{
        name: 'location',
        type: 'string',
        description: 'Stadt oder Postleitzahl',
        required: true
    }]
});

// Callback für die Tool-Ausführung
tool.executeCallback = function(args, callback) {
    var location = args.location;
    // Wetter-API aufrufen...
    var result = { temperature: 22, condition: 'sunny' };
    callback(result);
};
```

#### `createDownloader(args)` → `LiteRTLMModelDownloader`

Erstellt einen Model-Downloader.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `modelsDirectory` | `String` | Verzeichnis zum Speichern von Modellen |

#### `createModelInfo(args)` → `LiteRTLMModelInfo`

Erstellt ein ModelInfo-Objekt für das Herunterladen.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Interner Modellname |
| `displayName` | `String` | Anzeige-Name |
| `url` | `String` | Download-URL |
| `expectedSize` | `Int64` | Erwartete Dateigröße in Bytes |
| `fileName` | `String` | Dateiname nach dem Download |

---

### `LiteRTLMEngine`

Repräsentiert eine geladene LLM-Engine.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `status` | `String` | `'notLoaded'`, `'loaded'`, `'loading'`, `'error'` |
| `isReady` | `Boolean` | Ob die Engine bereit ist |
| `lastError` | `String` | Fehlermeldung oder `null` |
| `configuration` | `LiteRTLMEngineConfiguration` | Konfiguration der Engine |

#### Methoden

##### `load()` → `undefined`

Lädt das Modell in den Speicher.

```javascript
engine.load();
```

##### `unload()` → `undefined`

Entlastet das Modell aus dem Speicher.

```javascript
engine.unload();
```

##### `createSession(config?)` → `undefined`

Erstellt eine neue Session.

**Parameter:**

- `config` (`LiteRTLMSessionConfiguration`, optional)

**Ereignisse:**

- `sessioncreated` – Session erfolgreich erstellt
  - `session`: `LiteRTLMSession` Proxy-Objekt

```javascript
engine.createSession();
```

##### `createSessionWithConfig(config)` → `undefined`

Erstellt eine Session mit Konfiguration.

```javascript
var config = litertlm.createSessionConfigProxy({
    maxOutputTokens: 512,
    samplerType: 'balanced'
});
engine.createSessionWithConfig(config);
```

##### `createConversation(config?)` → `undefined`

Erstellt eine neue Conversation.

**Ereignisse:**

- `conversationcreated` – Conversation erfolgreich erstellt
  - `conversation`: `LiteRTLMConversation` Proxy-Objekt

```javascript
engine.createConversation();
```

##### `createConversationWithConfig(config)` → `undefined`

Erstellt eine Conversation mit Konfiguration.

```javascript
var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'Du bist ein hilfreicher Assistent.',
    maxOutputTokens: 1024,
    toolExecutionMode: 'auto'
});
engine.createConversationWithConfig(config);
```

---

### `LiteRTLMEngineConfiguration`

Konfiguration für die Engine.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `modelPath` | `String` | Pfad zum Modell |
| `primaryBackend` | `String` | `'cpu'` oder `'gpu'` |
| `visionBackend` | `String` | Vision-Backend |
| `audioBackend` | `String` | Audio-Backend |
| `maxTokens` | `Int32` | Maximale Tokens |
| `cacheDir` | `String` | Cache-Verzeichnis |
| `isBenchmarkEnabled` | `Boolean` | Benchmarking aktiv |
| `logLevel` | `String` | Log-Stufe |

---

### `LiteRTLMSession`

Repräsentiert eine einzelne Inferenz-Session (einzelne Anfrage).

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `isActive` | `Boolean` | Ob die Session aktiv ist |

#### Methoden

##### `generate(text, config?)` → `undefined`

Generiert Text als Antwort auf eine Eingabe.

```javascript
session.generate('Was ist KI?');
```

**Ereignisse:**

- `generateready` – Generierung abgeschlossen
  - `result`: `String` – Die generierte Antwort
  - `benchmarkInfo`: `Object` (optional) – Leistungsinformationen

- `generateerror` – Fehler bei der Generierung
  - `message`: `String` – Fehlermeldung

##### `generateMultimodal(contents, config?)` → `undefined`

Generiert eine Antwort auf mehrmodale Eingabe (Text + Bilder + Audio).

```javascript
var textContent = litertlm.createContentProxy({ type: 'text', text: 'Was siehst du auf dem Bild?' });
var imageContent = litertlm.createContentProxy({
    type: 'image',
    imageData: imageBlob,
    maxDimension: 1024
});

session.generateMultimodal([textContent, imageContent]);
```

##### `generateStream(text, config?)` → `undefined`

Startet einen Streaming-Generierungsprozess.

```javascript
session.generateStream('Erzähle eine Geschichte.');
```

**Ereignisse:**

- `streamstart` – Streaming gestartet
  - `sessionId`: `String` – ID der Session

- `token` – Neues Token empfangen
  - `token`: `String` – Das empfangene Token

- `streamcomplete` – Streaming abgeschlossen
  - `result`: `String` – Vollständige Antwort
  - `benchmarkInfo`: `Object` (optional)

- `streamerror` – Fehler beim Streaming
  - `message`: `String` – Fehlermeldung

- `streamend` – Streaming beendet (unabhängig vom Ergebnis)

##### `collectStream(text, config?)` → `undefined`

Startet Streaming und sammelt alle Tokens in einem Ergebnis.

```javascript
session.collectStream('Erkläre Quantenphysik einfach.');
```

##### `close()` → `undefined`

Schließt die Session.

```javascript
session.close();
```

##### `benchmarkInfo` → `Object`

Gibt Performance-Informationen zurück.

```javascript
var info = session.benchmarkInfo;
console.log('Token/s: ' + info.tokensPerSecond);
console.log('Zeit: ' + info.latencyMs + 'ms');
```

---

### `LiteRTLMSessionConfiguration`

Konfiguration für eine Session.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `maxOutputTokens` | `Int32` | Maximale Output-Token |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |
| `temperature` | `Float` | Temperatur (0.0–2.0) |
| `topK` | `Int32` | Top-K-Wert |
| `topP` | `Float` | Top-P-Wert (Nukleare Abtastung) |
| `seed` | `Int32` | Zufalls-Seed |

---

### `LiteRTLMConversation`

Repräsentiert eine mehrfache Conversation mit History.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `isActive` | `Boolean` | Ob die Conversation aktiv ist |
| `history` | `Array` | Liste von `LiteRTLMMessage`-Objekten |

#### Methoden

##### `send(message, config?)` → `undefined`

Sendet eine Nachricht und erhält eine Antwort.

```javascript
var message = litertlm.createMessageProxy({
    role: 'user',
    contents: [textContent]
});

conversation.send(message);
```

**Ereignisse:**

- `messagecomplete` – Antwort vollständig
  - `message`: `LiteRTLMMessage` – Antwort des Modells
  - `benchmarkInfo`: `Object` (optional)

- `messageerror` – Fehler beim Senden
  - `message`: `String` – Fehlermeldung

##### `sendMultimodal(message, config?)` → `undefined`

Sendet eine mehrmodale Nachricht.

```javascript
var message = litertlm.createMessageProxy({
    role: 'user',
    contents: [textContent, imageContent]
});

conversation.sendMultimodal(message);
```

##### `sendStream(message, config?)` → `undefined`

Sendet eine Nachricht mit Streaming-Antwort.

**Ereignisse:**

- `streamstart` – Streaming gestartet
- `token` – Neues Token (siehe Session)
- `streamcomplete` – Streaming abgeschlossen
- `streamerror` – Fehler
- `streamend` – Streaming beendet

##### `collectStream(message, config?)` → `undefined`

Sammelt alle Tokens einer Streaming-Antwort.

##### `cancel()` → `undefined`

Bricht die aktuelle Anfrage ab.

```javascript
conversation.cancel();
```

##### `close()` → `undefined`

Schließt die Conversation.

```javascript
conversation.close();
```

##### `getHistory()` → `Array`

Gibt den Conversation-Verlauf zurück.

```javascript
var history = conversation.getHistory();
console.log('Nachrichten im Verlauf: ' + history.length);
```

---

### `LiteRTLMConversationConfiguration`

Konfiguration für eine Conversation.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `maxOutputTokens` | `Int32` | Maximale Output-Token |
| `samplerType` | `String` | Sampler-Typ |
| `tools` | `Array` | Liste von Tools |
| `toolExecutionMode` | `String` | `'auto'`, `'required'`, `'disabled'` |
| `maxImageDimension` | `Int` | Maximale Bildgröße |
| `systemPrompt` | `String` | System-Prompt |

---

### `LiteRTLMSamplerConfiguration`

Feinkörnige Sampler-Konfiguration.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `temperature` | `Float` | Temperatur (0.0–2.0) |
| `topK` | `Int32` | Top-K-Wert |
| `topP` | `Float` | Top-P-Wert |
| `seed` | `Int32` | Zufalls-Seed |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### Statische Methoden

```javascript
// Greedy (deterministisch, niedrigste Temperatur)
var greedyConfig = litertlm.createSamplerConfigProxy();
greedyConfig.temperature = 0.0;
greedyConfig.topK = 1;

// Balanced (Standard)
var balancedConfig = litertlm.createSamplerConfigProxy();
balancedConfig.temperature = 0.7;

// Creative (höchste Temperatur)
var creativeConfig = litertlm.createSamplerConfigProxy();
creativeConfig.temperature = 1.5;
creativeConfig.topP = 0.95;
```

---

### `LiteRTLMContent`

Ein Content-Objekt (Text, Bild oder Audio).

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Textinhalt |
| `imageData` | `Ti.Blob` | Bilddaten |
| `audioData` | `Ti.Blob` | Audiodaten |
| `audioFormat` | `String` | Audio-Format |
| `maxDimension` | `Int` | Maximale Abmessung |

**Hilfsfunktionen:**

```javascript
// Text-Content
var textContent = litertlm.createContentProxy({
    type: 'text',
    text: 'Hallo Welt!'
});

// Bild-Content
var imageContent = litertlm.createContentProxy({
    type: 'image',
    imageData: imageBlob,
    maxDimension: 1024
});

// Audio-Content
var audioContent = litertlm.createContentProxy({
    type: 'audio',
    audioData: audioBlob,
    audioFormat: 'wav'
});
```

---

### `LiteRTLMMessage`

Eine Message in einer Conversation.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | Liste von Content-Objekten |

---

### `LiteRTLMTool`

Ein Tool (Function) für das Tool Calling.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Funktionsname |
| `description` | `String` | Funktionsbeschreibung |
| `parameters` | `Array` | Parameter-Definitionen |
| `executeCallback` | `Function` | Callback für die Ausführung |

---

### `LiteRTLMModelInfo`

Informationen über ein Modell.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `name` | `String` | Modellname |
| `displayName` | `String` | Anzeige-Name |
| `url` | `String` | Download-URL |
| `expectedSize` | `Int64` | Erwartete Größe |
| `fileName` | `String` | Dateiname |
| `status` | `String` | `'unknown'`, `'available'`, `'downloading'`, `'downloading'`, `'downloaded'`, `'error'` |

#### Statische Modelle

```javascript
// Google Gemma 2B
var gemma2b = litertlm.createModelInfo({
    name: 'gemma-2b-it',
    displayName: 'Gemma 2B It',
    url: 'https://...',
    expectedSize: 5000000000,
    fileName: 'gemma-2b-it'
});

// Google Gemma 7B
var gemma7b = litertlm.createModelInfo({
    name: 'gemma-7b-it',
    displayName: 'Gemma 7B It',
    url: 'https://...',
    expectedSize: 15000000000,
    fileName: 'gemma-7b-it'
});
```

---

### `LiteRTLMModelDownloader`

Model-Downloader für das Herunterladen und Verwalten von Modellen.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `modelsDirectory` | `String` | Verzeichnis der Modelle |

#### Methoden

##### `download(modelInfo)` → `undefined`

Startet den Download eines Modells.

```javascript
downloader.download(modelInfo);
```

**Ereignisse:**

- `downloadstart` – Download gestartet
- `downloadprogress` – Download-Fortschritt
  - `progress`: `Float` (0.0–1.0)
  - `bytesDownloaded`: `Int64`
  - `totalBytes`: `Int64`
- `downloadcomplete` – Download abgeschlossen
  - `modelInfo`: `LiteRTLMModelInfo`
- `downloaderror` – Fehler beim Download
  - `message`: `String`

##### `downloadFrom(url, fileName?, expectedSize?)` → `undefined`

Lädt ein Modell von einer URL herunter.

```javascript
downloader.downloadFrom(
    'https://example.com/model.gguf',
    'my-model.gguf',
    5000000000
);
```

##### `pause()` → `undefined`

Pausiert den aktuellen Download.

```javascript
downloader.pause();
```

##### `cancel()` → `undefined`

Bricht den Download ab.

```javascript
downloader.cancel();
```

##### `isDownloaded(modelInfo)` → `Boolean`

Prüft, ob ein Modell heruntergeladen ist.

```javascript
var exists = downloader.isDownloaded(modelInfo);
if (exists) {
    console.log('Model already downloaded');
} else {
    downloader.download(modelInfo);
}
```

##### `modelPath(modelInfo)` → `String`

Gibt den Pfad zum Modell zurück.

```javascript
var path = downloader.modelPath(modelInfo);
console.log('Model path: ' + path);
```

##### `deleteModel(modelInfo)` → `undefined`

Löscht ein heruntergeladenes Modell.

```javascript
downloader.deleteModel(modelInfo);
```

##### `deleteModelByFileName(fileName)` → `undefined`

Löscht ein Modell nach Dateinamen.

```javascript
downloader.deleteModelByFileName('my-model.gguf');
```

---

## 🚀 Vollständiges Beispiel

Ein vollständiges Beispiel finden Sie im Ordner `example/app.js`. Es demonstriert:

- Modell-Download und -Verwaltung
- Engine-Initialisierung
- Einfache Textgenerierung
- Streaming-Ausgabe
- Conversation mit History
- Tool Calling
- Mehrmodale Eingabe (Vision)
- Fehlerbehandlung

---

## 📡 Streaming API

Das Streaming ermöglicht Token-für-Token-Ausgabe in Echtzeit:

```javascript
// Einfaches Streaming
session.generateStream('Erzähle mir eine Geschichte über einen Roboter.');

session.addEventListener('streamstart', function(e) {
    console.log('Streaming started');
    outputText = '';
});

session.addEventListener('token', function(e) {
    // Jedes Token wird einzeln empfangen
    outputText += e.token;
    label.text = outputText; // Live-Update im UI
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

## 🛠️ Tool Calling / Function Calling

LLMs können Funktionen Ihrer App aufrufen:

```javascript
// 1. Tool definieren
var weatherTool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Holt das aktuelle Wetter für einen Ort',
    parameters: [{
        name: 'location',
        type: 'string',
        description: 'Stadt oder Postleitzahl',
        required: true
    }]
});

// 2. Callback setzen
weatherTool.executeCallback = function(args, callback) {
    Ti.API.info('Tool called with args: ' + JSON.stringify(args));
    
    // Externe API aufrufen
    var weatherData = getWeatherFromAPI(args.location);
    
    // Ergebnis zurückgeben
    callback({
        temperature: weatherData.temp,
        condition: weatherData.condition,
        humidity: weatherData.humidity
    });
};

// 3. Tool an Conversation übergeben
var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'Du bist ein hilfreicher Wetter-Assistent.',
    tools: [weatherTool],
    toolExecutionMode: 'auto'
});

engine.createConversationWithConfig(config);

// 4. Antwort des Modells verarbeiten
conversation.addEventListener('messagecomplete', function(e) {
    var message = e.message;
    if (message.role === 'model') {
        // Modell hat möglicherweise Tools aufgerufen
        console.log('Model response: ' + message.contents[0].text);
    }
});
```

---

## 🖼️ Mehrmodale Eingabe (Vision, Audio)

### Bilderkennung (Vision)

```javascript
// Bild aus der Fotomediathek auswählen
var imageDialog = Ti.UI.createOptionDialog({
    title: 'Bild auswählen',
    options: ['Kamera', 'Fotomediathek', 'Abbrechen'],
    cancel: 2,
    destruction: 2
});

imageDialog.show();
imageDialog.addEventListener('click', function(e) {
    if (e.index === 0) {
        // Kamera öffnen
        Ti.Media.openCamera({
            success: function(event) {
                var imageContent = litertlm.createContentProxy({
                    type: 'image',
                    imageData: event.media,
                    maxDimension: 1024
                });
                
                var textContent = litertlm.createContentProxy({
                    type: 'text',
                    text: 'Was siehst du auf diesem Bild?'
                });
                
                session.generateMultimodal([textContent, imageContent]);
            },
            cancel: function() {},
            error: function(error) {
                alert('Kamera-Fehler: ' + error);
            }
        });
    }
});
```

### Audio-Eingabe

```javascript
var audioContent = litertlm.createContentProxy({
    type: 'audio',
    audioData: audioBlob,
    audioFormat: 'wav'
});

session.generateMultimodal([audioContent]);
```

---

## 🐛 Fehlerbehandlung

Alle asynchronen Operationen können Fehler auslösen. Verwenden Sie immer Error-Listener:

```javascript
// Engine-Fehler
engine.addEventListener('error', function(e) {
    Ti.API.error('Engine error: ' + e.message);
    alert('Fehler: ' + e.message);
});

// Session-Fehler
session.addEventListener('generateerror', function(e) {
    Ti.API.error('Generation error: ' + e.message);
});

// Conversation-Fehler
conversation.addEventListener('messageerror', function(e) {
    Ti.API.error('Message error: ' + e.message);
});

// Streaming-Fehler
session.addEventListener('streamerror', function(e) {
    Ti.API.error('Streaming error: ' + e.message);
});

// Downloader-Fehler
downloader.addEventListener('downloaderror', function(e) {
    Ti.API.error('Download error: ' + e.message);
});
```

---

## 📥 Modell-Downloads

Das Modul unterstützt das Herunterladen von Modellen über HTTP/HTTPS:

```javascript
// Downloader erstellen
var downloader = litertlm.createDownloader({
    modelsDirectory: Ti.Filesystem.applicationDataDirectory + 'models/'
});

// Modell-Info erstellen
var modelInfo = litertlm.createModelInfo({
    name: 'gemma-2b-it',
    displayName: 'Gemma 2B It',
    url: 'https://storage.googleapis.com/gemma-2b-it/gemma-2b-it.gguf',
    expectedSize: 5000000000, // 5 GB
    fileName: 'gemma-2b-it.gguf'
});

// Download-Fortschritt anzeigen
downloader.addEventListener('downloadprogress', function(e) {
    progressIndicator.value = e.progress * 100;
    label.text = 'Download: ' + Math.round(e.progress * 100) + '%';
});

// Download starten
downloader.download(modelInfo);
```

---

## ⚡ Performance-Tipps

1. **GPU-Backend verwenden**: Wenn verfügbar, ist das GPU-Backend deutlich schneller als CPU.
   ```javascript
   engine.createEngineWithConfig({
       backend: 'gpu'
   });
   ```

2. **Model-Last/Entlastung**: Entlasten Sie Modelle, wenn sie nicht benötigt werden.
   ```javascript
   engine.unload(); // Speichern freige
   // ... später
   engine.load();   // Neu laden
   ```

3. **Cache-Verzeichnis**: Verwenden Sie ein Cache-Verzeichnis für schnellere Ladezeiten.
   ```javascript
   engine.createEngineWithConfig({
       cacheDir: Ti.Filesystem.applicationCachesDirectory
   });
   ```

4. **Maximale Token-Anzahl**: Setzen Sie `maxTokens`, um die Speichernutzung zu begrenzen.

5. **Batch-Verarbeitung**: Für mehrere Anfragen, verwenden Sie Sessions statt neuer Conversations.

---

## 🔍 Debugging

Aktivieren Sie den Debug-Modus für detaillierte Protokollierung:

```javascript
// In tiapp.xml
<property name="ti.logging" type="bool">true</property>

// Oder im Code
Ti.API.info = function(msg) {
    console.log('[LITERTLM] ' + msg);
};
```

Engine-Status überprüfen:

```javascript
console.log('Status: ' + engine.status);
console.log('Is ready: ' + engine.isReady);
console.log('Last error: ' + engine.lastError);
```

---

## 📌 Bekannte Einschränkungen

- **iOS nur**: Das Modul unterstützt derzeit nur iOS. Android ist in Planung.
- **Arm64 only**: x86_64-Simulator wird nicht unterstützt.
- **Modellgröße**: Modelle können 1–20 GB groß sein – genügend Speicherplatz einplanen.
- **Speicherverbrauch**: Geladene Modelle benötigen ~2–4x ihre Dateigröße im Arbeitsspeicher.
- **Kein Background-Modus**: LLM-Inferenz läuft nur im Vordergrund.
- **Kein Android**: Android-Unterstützung ist in der Roadmap.

---

## 🗺️ Roadmap

- [ ] **Android-Unterstützung**
- [ ] **Echtzeit-Spracherkennung (STT)**
- [ ] **Text-to-Speech (TTS)**
- [ ] **RAG (Retrieval-Augmented Generation)**
- [ ] **Multi-Modell-Unterstützung**
- [ ] **Web-View-Integration**
- [ ] **CI/CD-Pipeline**
- [ ] **Umfassende Tests**

---

## 📄 Lizenz

Dieses Projekt ist unter der [Apache License 2.0](LICENSE) lizenziert.

```
Copyright 2026 Marc Bender

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

## 👤 Autor

**Marc Bender**

- GitHub: [@marcbender](https://github.com/marcbender)
- E-Mail: marcbender@example.com

---

## 🤝 Beiträge

Beiträge sind willkommen! Bitte erstellen Sie ein Issue oder einen Pull Request.

1. Forken Sie das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/mein-feature`)
3. Committen Sie Ihre Änderungen (`git commit -am 'Add new feature'`)
4. Pushen Sie zum Branch (`git push origin feature/mein-feature`)
5. Erstellen Sie einen Pull Request

---

## 📞 Support

Bei Fragen oder Problemen:

- [GitHub Issues](https://github.com/marcbender/TitaniumLiteRTLM/issues)
- [GitHub Discussions](https://github.com/marcbender/TitaniumLiteRTLM/discussions)
- E-Mail: marcbender@example.com

---

**Viel Spaß beim Programmieren mit TitaniumLiteRTLM! 🚀**
 