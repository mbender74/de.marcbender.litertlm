# TitaniumLiteRTLM – API-Referenz

**Modul-ID:** `de.marcbender.litertlm`  
**Version:** 1.0.0  
**Plattform:** iOS (arm64)  
**Titanium SDK:** 13.2.0.GA+

---

## Übersicht

Das `de.marcbender.litertlm`-Modul packt das vollständige [Google LiteRTLM-Swift-SDK](https://github.com/google/litert) als Titanium-Modul ein. Es ermöglicht die Ausführung von Large Language Models (LLMs) direkt auf dem iOS-Gerät – ohne Netzwerkverbindung, ohne Cloud-Abhängigkeiten.

### Kernkonzepte

| Konzept | Beschreibung |
|---------|--------------|
| **Engine** | Lädt ein Modell und verwaltet die Inferenz-Engine. Eine Engine kann mehrere Sessions/Conversations enthalten. |
| **Session** | Eine einzelne Inferenz-Anfrage (ein Text → eine Antwort). Zustandslos. |
| **Conversation** | Eine mehrfache Unterhaltung mit History, System-Prompt und Tool Calling. Zustandbehaftet. |
| **Downloader** | Lädt Modelle von HuggingFace oder anderen URLs herunter und verwaltet sie lokal. |
| **Streaming** | Token-für-Token-Ausgabe in Echtzeit über Events. |
| **Tool Calling** | Das LLM kann Funktionen Ihrer App aufrufen und die Ergebnisse nutzen. |

---

## Installation

### Voraussetzungen

- iOS 17.0+
- Titanium SDK 13.2.0.GA oder neuer
- Xcode 15.0+
- Apple Silicon Mac oder iPhone/iPad (arm64)

### Modul installieren

1. Bauen Sie das Modul:
   ```bash
   cd ios
   ti build -p ios --build-only
   ```

2. Das ZIP entsteht im Ordner `ios/dist/`. Kopieren Sie es in Ihr Projekt:
   ```bash
   cp dist/de.marcbender.litertlm-iphone-1.0.0.zip /path/to/your-project/modules/
   ```

### tiapp.xml konfigurieren

Fügen Sie das Modul in Ihre `tiapp.xml` ein:

```xml
<modules>
    <module version="1.0.0" platform="ios">de.marcbender.litertlm</module>
</modules>
```

### Berechtigungen in tiapp.xml

Für Kamera, Mikrofon und Fotomediathek:

```xml
<property name="ti.android.bundle.url" type="string"></property>
<ios>
    <plist>
        <dict>
            <key>NSCameraUsageDescription</key>
            <string>Bilder für die KI-Erkennung aufnehmen</string>
            <key>NSMicrophoneUsageDescription</key>
            <string>Spracheingabe für die KI</string>
            <key>NSPhotoLibraryUsageDescription</key>
            <string>Bilder aus der Fotomediathek auswählen</string>
        </dict>
    </plist>
</ios>
```

---

## JavaScript-API-Referenz

### Zugriff auf das Modul

```javascript
var litertlm = require('de.marcbender.litertlm');
```

### Methoden des Hauptmoduls

#### `litertlm.getVersion()` → `String`

Gibt die Versionsnummer des Moduls zurück.

```javascript
var version = litertlm.getVersion(); // "1.0.0"
```

#### `litertlm.createEngine(arguments)`

Erstellt und lädt eine Engine mit einem Modell.

**Parameter (`arguments`):**

| Schlüssel | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `modelPath` | `String` | *erforderlich* | Pfad zur Modell-Datei oder -Verzeichnis |
| `backend` | `String` | `'cpu'` | `'cpu')` oder `'gpu'` |
| `maxTokens` | `Int32` | `0` | Maximale Anzahl generierter Tokens (0 = unbegrenzt) |
| `cacheDir` | `String` | `null` | Cache-Verzeichnis für das Modell |
| `benchmarkEnabled` | `Boolean` | `false` | Leistungsmessung aktivieren |
| `logLevel` | `String` | `'warning'` | `'error'`, `'warning'`, `'info'`, `'fatal'`, `'silent'` |

**Ereignisse:**

| Name | Beschreibung | Payload |
|------|--------------|---------|
| `enginecreated` | Engine erfolgreich geladen | `{ engine: LiteRTLMEngine }` |

**Beispiel:**

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

Erstellt eine Engine mit einem Konfigurations-Objekt (siehe `createEngineConfigProxy`).

```javascript
var config = litertlm.createEngineConfigProxy({
    modelPath: '/path/to/model',
    backend: 'gpu'
});
litertlm.createEngineWithConfig(config);
```

#### `litertlm.createEngineConfigProxy(arguments)` → `LiteRTLMEngineConfiguration`

Erstellt ein Engine-Konfigurations-Objekt.

**Parameter (`arguments`):**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `modelPath` | `String` | Pfad zum Modell |
| `backend` | `String` | `'cpu'` oder `'gpu'` |
| `maxTokens` | `Int32` | Maximale Tokens |
| `cacheDir` | `String` | Cache-Verzeichnis |
| `benchmarkEnabled` | `Boolean` | Benchmarking aktivieren |
| `logLevel` | `String` | Log-Stufe |
| `visionBackend` | `String` | Backend für Vision/Bilder |
| `audioBackend` | `String` | Backend für Audio |

#### `litertlm.createSessionConfigProxy(arguments)` → `LiteRTLMSessionConfiguration`

Erstellt eine Session-Konfiguration.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `maxOutputTokens` | `Int32` | Maximale Output-Token |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `litertlm.createConversationConfigProxy(arguments)` → `LiteRTLMConversationConfiguration`

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

#### `litertlm.createSamplerConfigProxy(arguments)` → `LiteRTLMSamplerConfiguration`

Erstellt eine Sampler-Konfiguration.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `temperature` | `Double` | 0.0–2.0 (niedrig = deterministisch, hoch = kreativ) |
| `topK` | `Int32` | Top-K-Wert (nur die besten K Tokens) |
| `topP` | `Double` | Nukleare Abtastung (0.0–1.0) |
| `seed` | `Int32` | Zufalls-Seed für Reproduzierbarkeit |
| `samplerType` | `String` | `'greedy'`, `'balanced'`, `'creative'` |

#### `litertlm.createContentProxy(arguments)` → `LiteRTLMContent`

Erstellt ein Content-Objekt.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `type` | `String` | `'text'`, `'image'`, `'audio'` |
| `text` | `String` | Textinhalt |
| `imageData` | `Ti.Blob` | Bilddaten |
| `audioData` | `Ti.Blob` | Audiodaten |
| `audioFormat` | `String` | Audio-Format (z.B. `'wav'`, `'mp3'`) |
| `maxDimension` | `Int` | Maximale Bildabmessung |

#### `litertlm.createMessageProxy(arguments)` → `LiteRTLMMessage`

Erstellt eine Message (Nutzlast) für eine Conversation.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | Liste von `LiteRTLMContent`-Objekten |

#### `litertlm.createToolProxy(arguments)` → `LiteRTLMTool`

Erstellt ein Tool (Function) für das Tool Calling.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Name der Funktion |
| `description` | `String` | Beschreibung, was die Funktion tut |
| `parameters` | `Array` | Parameter-Definitionen |

Jeder Parameter ist ein Objekt mit:

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Name des Parameters |
| `type` | `String` | `'string'`, `'number'`, `'boolean'`, `'object'`, `'array'` |
| `description` | `String` | Beschreibung des Parameters |
| `required` | `Boolean` | Ob der Parameter erforderlich ist |

#### `litertlm.createDownloader(arguments)` → `LiteRTLMModelDownloader`

Erstellt einen Model-Downloader.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `modelsDirectory` | `String` | Verzeichnis zum Speichern von Modellen |

**Ereignisse:**

| Name | Beschreibung | Payload |
|------|--------------|---------|
| `downloadprogress` | Download-Fortschritt | `{ progress: Float, bytesDownloaded: Int64, totalBytes: Int64 }` |
| `downloadcomplete` | Download abgeschlossen | `{ modelInfo: LiteRTLMModelInfo }` |
| `downloaderror` | Fehler beim Download | `{ message: String }` |

#### `litertlm.createModelInfo(arguments)` → `LiteRTLMModelInfo`

Erstellt ein ModelInfo-Objekt.

**Parameter:**

| Schlüssel | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Interner Modellname |
| `displayName` | `String` | Anzeige-Name |
| `url` | `String` | Download-URL |
| `expectedSize` | `Int64` | Erwartete Dateigröße in Bytes |
| `fileName` | `String` | Dateiname nach dem Download |

---

### LiteRTLMEngine

Repräsentiert eine geladene LLM-Engine.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `status` | `String` | `'notLoaded'`, `'loaded'`, `'loading'`, `'error'` |
| `isReady` | `Boolean` | Ob die Engine bereit ist |
| `lastError` | `String` | Fehlermeldung oder `null` |

#### Methoden

##### `engine.load()`

Lädt das Modell in den Speicher.

##### `engine.unload()`

Entlastet das Modell aus dem Speicher.

##### `engine.createSession(config?)`

Erstellt eine neue Session.

**Ereignisse:** `sessioncreated` mit `{ session: LiteRTLMSession }`

##### `engine.createSessionWithConfig(config)`

Erstellt eine Session mit Konfiguration.

##### `engine.createConversation(config?)`

Erstellt eine neue Conversation.

**Ereignisse:** `conversationcreated` mit `{ conversation: LiteRTLMConversation }`

##### `engine.createConversationWithConfig(config)`

Erstellt eine Conversation mit Konfiguration.

---

### LiteRTLMSession

Repräsentiert eine einzelne Inferenz-Session.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `isActive` | `Boolean` | Ob die Session aktiv ist |

#### Methoden

##### `session.generate(text, config?)`

Generiert Text als Antwort.

**Ereignisse:**

| Name | Beschreibung | Payload |
|------|--------------|---------|
| `generateready` | Generierung abgeschlossen | `{ result: String, benchmarkInfo: Object }` |
| `generateerror` | Fehler bei der Generierung | `{ message: String }` |

##### `session.generateMultimodal(contents, config?)`

Generiert eine Antwort auf mehrmodale Eingabe (Text + Bilder + Audio).

**Ereignisse:** wie `generate`, aber mit multimodaler Verarbeitung.

##### `session.generateStream(text, config?)`

Startet Streaming-Generierung.

**Ereignisse:**

| Name | Beschreibung | Payload |
|------|--------------|---------|
| `streamstart` | Streaming gestartet | `{ sessionId: String }` |
| `token` | Neues Token | `{ token: String }` |
| `streamcomplete` | Streaming abgeschlossen | `{ result: String, benchmarkInfo: Object }` |
| `streamerror` | Fehler beim Streaming | `{ message: String }` |
| `streamend` | Streaming beendet | – |

##### `session.collectStream(text, config?)`

Sammelt alle Tokens einer Streaming-Antwort in einem Ergebnis.

##### `session.close()`

Schließt die Session.

---

### LiteRTLMConversation

Repräsentiert eine Conversation mit History.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `isActive` | `Boolean` | Ob die Conversation aktiv ist |
| `history` | `Array` | Liste von `LiteRTLMMessage`-Objekten |

#### Methoden

##### `conversation.send(message, config?)`

Sendet eine Nachricht und erhält eine Antwort.

**Ereignisse:**

| Name | Beschreibung | Payload |
|------|--------------|---------|
| `messagecomplete` | Antwort vollständig | `{ message: LiteRTLMMessage }` |
| `messageerror` | Fehler beim Senden | `{ message: String }` |

##### `conversation.sendMultimodal(message, config?)`

Sendet eine mehrmodale Nachricht.

##### `conversation.sendStream(message, config?)`

Sendet eine Nachricht mit Streaming-Antwort.

**Ereignisse:** wie bei `generateStream`.

##### `conversation.collectStream(message, config?)`

Sammelt alle Tokens einer Streaming-Antwort.

##### `conversation.cancel()`

Bricht die aktuelle Anfrage ab.

##### `conversation.close()`

Schließt die Conversation.

##### `conversation.getHistory()` → `Array`

Gibt den Conversation-Verlauf zurück.

---

### LiteRTLMContent

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

---

### LiteRTLMMessage

Eine Message in einer Conversation.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `role` | `String` | `'user'`, `'model'`, `'system'` |
| `contents` | `Array` | Liste von Content-Objekten |

---

### LiteRTLMTool

Ein Tool (Function) für das Tool Calling.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-----------|-----|--------------|
| `name` | `String` | Funktionsname |
| `description` | `String` | Funktionsbeschreibung |
| `parameters` | `Array` | Parameter-Definitionen |
| `executeCallback` | `Function` | Callback für die Ausführung |

#### executeCallback

Der Callback wird aufgerufen, wenn das LLM das Tool aufruft:

```javascript
tool.executeCallback = function(args, callback) {
    // args: Parameter, die das LLM übermittelt hat
    // callback: Funktion, um das Ergebnis zurückzugeben

    var result = { temperature: 22, condition: 'sunny' };
    callback(result);
};
```

---

### LiteRTLMModelInfo

Informationen über ein Modell.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `name` | `String` | Modellname |
| `displayName` | `String` | Anzeige-Name |
| `url` | `String` | Download-URL |
| `expectedSize` | `Int64` | Erwartete Größe in Bytes |
| `fileName` | `String` | Dateiname |

---

### LiteRTLMModelDownloader

Model-Downloader für das Herunterladen und Verwalten von Modellen.

#### Eigenschaften

| Eigenschaft | Typ | Beschreibung |
|-------------|-----|--------------|
| `modelsDirectory` | `String` | Verzeichnis der Modelle |

#### Methoden

##### `downloader.download(modelInfo)`

Startet den Download eines Modells.

##### `downloader.downloadFrom(url, fileName?, expectedSize?)`

Lädt ein Modell von einer URL herunter.

##### `downloader.pause()`

Pausiert den aktuellen Download.

##### `downloader.cancel()`

Bricht den Download ab.

##### `downloader.isDownloaded(modelInfo)` → `Boolean`

Prüft, ob ein Modell heruntergeladen ist.

##### `downloader.modelPath(modelInfo)` → `String`

Gibt den Pfad zum Modell zurück.

##### `downloader.deleteModel(modelInfo)`

Löscht ein heruntergeladenes Modell.

##### `downloader.deleteModelByFileName(fileName)`

Löscht ein Modell nach Dateinamen.

---

## Nutzungshinweise

### Modell-Download

Das Modul unterstützt den Download von Modellen über HTTP/HTTPS von HuggingFace oder anderen Quellen:

```javascript
var downloader = litertlm.createDownloader({
    modelsDirectory: Ti.Filesystem.applicationStorageDirectory + 'models/'
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

### Stream-Verarbeitung

```javascript
session.generateStream('Erzählen Sie eine Geschichte.');

session.addEventListener('token', function(e) {
    // Jedes Token wird einzeln empfangen
    outputText += e.token;
    label.text = outputText; // Live-Update im UI
});

session.addEventListener('streamcomplete', function(e) {
    console.log('Antwort: ' + e.result);
});
```

### Tool Calling

```javascript
var tool = litertlm.createToolProxy({
    name: 'get_weather',
    description: 'Holt das aktuelle Wetter für eine Stadt',
    parameters: [{
        name: 'city',
        type: 'string',
        description: 'Stadtnamen',
        required: true
    }]
});

tool.executeCallback = function(args, callback) {
    var weather = getWeatherFromAPI(args.city);
    callback(weather);
};

var config = litertlm.createConversationConfigProxy({
    systemPrompt: 'Sie sind ein hilfreicher Assistent.',
    tools: [tool],
    toolExecutionMode: 'auto'
});

engine.createConversationWithConfig(config);
```

### Fehlerbehandlung

```javascript
// Engine-Fehler
engine.addEventListener('error', function(e) {
    Ti.API.error('Engine error: ' + e.message);
});

// Session-Fehler
session.addEventListener('generateerror', function(e) {
    Ti.API.error('Generation error: ' + e.message);
});

// Downloader-Fehler
downloader.addEventListener('downloaderror', function(e) {
    Ti.API.error('Download error: ' + e.message);
});
```

---

## Bekannte Einschränkungen

- **iOS nur**: Android-Unterstützung ist in der Roadmap.
- **Arm64 only**: x86_64-Simulator wird nicht unterstützt.
- **Speicherbedarf**: Geladene Modelle benötigen ca. 2–4× ihre Dateigröße im Arbeitsspeicher.
- **Kein Background-Modus**: LLM-Inferenz läuft nur im Vordergrund.
- **Modellgröße**: Modelle können 1–20 GB groß sein.

---

## Lizenz

Apache License 2.0

---

## Autor

Marc Bender – [marcbender@example.com](mailto:marcbender@example.com)
