# TitaniumLiteRTLM – Projektstatus & Architektur

## Projekt-Übersicht

- **Modul-ID:** `de.marcbender.litertlm`
- **Version:** 1.0.0
- **Ziel:** Titanium iOS-Modul, das Google LiteRTLM-Swift-SDK für On-Device LLM-Inferenz umschließt
- **Test-App:** `/Users/marcbender/example/testApp`
- **Referenz-Module:**
  - `/Users/marcbender/Downloads/ti.circularprogress-main` (funktionierendes TiProxy-Beispiel)
  - `/Users/marcbender/Downloads/ti.cardscanner-main` (Facade-Pattern für externe Swift-Typen)

## Build & Install

```bash
# Modul bauen
cd /Users/marcbender/TitaniumLiteRTLM/ios && ti build -p ios --build-only

# In testApp installieren
cd /Users/marcbender/example/testApp && rm -rf modules/iphone/de.marcbender.litertlm && \
  unzip -o /Users/marcbender/TitaniumLiteRTLM/ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip -d modules/iphone/

# testApp kompilieren (manuell in Xcode oder via ti build)
```

## Debugging

```bash
# Module-Logs in separatem Terminal (vor App-Start)
log stream --predicate 'message contains "[DEBUG]"'
```

## Architektur

### Dateistruktur

```
ios/Classes/
├── DeMarcbenderLitertlmModule.swift       # Haupt-Modul (TiModule) – CLiteRTLM importiert
├── LiteRTLMModelDownloaderProxy.swift     # Downloader Proxy (TiProxy) – kein externer Import
├── LiteRTLMEngineProxy.swift              # Engine Proxy
├── LiteRTLMConversationProxy.swift        # Conversation Proxy
├── LiteRTLMEngineConfiguration.swift      # Engine-Config Proxy
├── LiteRTLMConversationConfiguration.swift # Conversation-Config Proxy
├── LiteRTLMSessionProxy.swift             # Session Proxy
├── LiteRTLMSessionConfiguration.swift     # Session-Config Proxy
├── LiteRTLMSamplerConfiguration.swift     # Sampler-Config Proxy
├── LiteRTLMContent.swift                  # Content Proxy
├── LiteRTLMMessage.swift                  # Message Proxy
├── LiteRTLMTool.swift                     # Tool Proxy
├── LiteRTLMModelInfo.swift                # ModelInfo Proxy
└── LiteRTLMDownloader/
    ├── ModelDownloader.swift               # @Observable, macht URLSession-Downloads
    ├── ModelInfo.swift                     # Swift struct mit Modell-Metadaten
    └── DownloadState.swift                 # enum: idle, downloading, paused, completed, failed
```

### Kern-Patterns

#### 1. TiProxy Init-Pattern

**Falsch (crashed):**
```swift
override init() {
    _downloader = ModelDownloader()  // ❌ Swift metadata init crasht
    super.init()
}
```

**Richtig (Referenz: ti.circularprogress):**
```swift
override init() {
    super.init()  // ✅ Erst super, dann keine externen Swift-Typen initialisieren
}

override public func _init(withProperties properties: [AnyHashable : Any]!) {
    super._init(withProperties: properties)
    // ✅ Properties aus JS extrahieren, keine externen Typen
}
```

#### 2. Externe Swift-Typen in Proxies vermeiden

**Problem:** TiProxy-Subklassen, die `CLiteRTLM` importieren und externe Swift-Typen in `@objc`-Method-Signaturen verwenden, triggern Swift Metadata Initialization, die crasht weil der Titanium Page Context noch nicht gesetzt ist.

**Lösung (Facade-Pattern):**
- **Proxy:** Kein `CLiteRTLM`/`ModelDownloader` Import, alle Parameter als `Any?`
- **Modul:** Alle CLiteRTLM-Arbeit via Delegation-Methoden
- **Kommunikation:** Proxy ruft Modul-Methoden über `_moduleRef` auf

```swift
// LiteRTLMModelDownloaderProxy.swift – kein externer Import
@objc(LiteRTLMModelDownloaderProxy)
public class LiteRTLMModelDownloaderProxy: TiProxy {
  @objc public func download(_ modelInfo: Any?) {
    module().delegateDownload(with: modelInfo, proxy: self)
  }
  private func module() -> DeMarcbenderLitertlmModule? {
    return DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule
  }
}

// DeMarcbenderLitertlmModule.swift – CLiteRTLM importiert, macht die Arbeit
func delegateDownload(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) {
  let dl = downloader()  // ModelDownloader
  // ... download logic
}
```

#### 3. JS-Argumente-Handling

JS-Objekte kommen als `NSArray` an (erstes Element = params dict):

```swift
@objc(createDownloader:)
func createDownloader(arguments: [Any]?) -> Any? {
  guard let params = arguments?.first as? [String: Any] else { return nil }
  // ...
}
```

Für Proxy-Methoden die vom Modul aufgerufen werden:

```swift
func delegateDownload(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) {
  let args = modelInfo as? [Any] ?? []
  let params = args.first as? [AnyHashable: Any]
  // ...
}
```

#### 4. Property-Typen in TiProxy

| Typ | Status | Beispiel |
|-----|--------|----------|
| `NSString?` | ✅ Sicher | `private var _modelsDirectory: NSString?` |
| `NSNumber` | ✅ Sicher | `@objc var progressValue: NSNumber` |
| `Bool`, `String`, `Int` | ✅ Sicher | Primitive Typen |
| `AnyObject?` | ✅ Sicher | Für Swift-Objekte ohne Typ |
| `ModelDownloader?` | ❌ Crashed | Externer Swift-Typ in TiProxy |
| `LiteRTLMModelInfo` | ❌ Crashed | Externer Swift-Typ als @objc-Parameter |

#### 5. ModelDownloader Progress Reporting

`ModelDownloader` ist `@Observable` – keine Callback-Parameter. Progress wird via Polling abgerufen:

```swift
private func pollDownload(proxy: LiteRTLMModelDownloaderProxy, work: @escaping () async -> Void) async {
  let dl = self.downloader()
  let pollTask = Task.detached(priority: .utility) {
    while true {
      try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
      let state = dl.state
      switch state {
      case .downloading:
        proxy.fireEvent("downloadprogress", with: [
          "progress": dl.progress,
          "bytesDownloaded": dl.downloadedBytes,
          "totalBytes": dl.totalBytes ?? 0
        ])
      case .completed:
        proxy.fireEvent("downloadcomplete", with: [...])
      case .failed(let message):
        proxy.fireEvent("downloaderror", with: ["message": message])
      default: break
      }
    }
  }
  await work()
  pollTask.cancel()
}
```

## Crash-Fix Historie

| Commit | Problem | Lösung |
|--------|---------|--------|
| `4f1cb89` | `createDownloader` gab Proxy nicht an JS zurück | `return proxy` hinzufügen |
| `b49af4f` | Swift-Objekte wurden freigegeben | Strong `_downloader: AnyObject?` Property |
| `3845720` | ExampleProxy crasht bei Swift metadata | Instance in `startup()` erstellen, nicht lazy |
| `e99ee7f` | SIGSEGV in `swift_retain` bei `createDownloader()` | **Facade-Pattern**: Proxy ohne CLiteRTLM-Import, Delegation ins Modul, `[AnyHashable: Any]` Cast |

## Aktueller Status

### ✅ Funktioniert
- Modul-Startup ohne Crash
- `createDownloader()` ohne Crash
- `downloader.isDownloaded(modelInfo)` ohne Crash
- `downloader.download(modelInfo)` – Download startet korrekt
- Progress-Events: `downloadprogress`, `downloadcomplete`, `downloaderror`
- `getVersion()`, `example()`

### 🔧 TODO
- [ ] Engine-Initialisierung mit `createEngineWithConfig()` testen
- [ ] Conversation erstellen und `sendStream()` testen
- [ ] Alle anderen TiProxy-Klassen auf `CLiteRTLM`-Import prüfen und ggf. refactoren
- [ ] Tool Calling implementieren
- [ ] Multimodale Eingabe (Bilder, Audio) testen
- [ ] Voice Recording implementieren

### 📝 Open Questions
- [`LiteRTLMEngineProxy`](ios/Classes/LiteRTLMEngineProxy.swift) – hält `LMEngine` (externer Typ), muss refactored werden?
- [`LiteRTLMConversationProxy`](ios/Classes/LiteRTLMConversationProxy.swift) – hält `Conversation`, muss refactored werden?
- Sollten alle Proxy-Klassen das gleiche Facade-Pattern verwenden?

## Logging

Alle Debug-Logs verwenden `NSLog("[DEBUG] ...")` und erscheinen in:
- `log stream --predicate 'message contains "[DEBUG]"'` (Terminal)
- macOS Console.app
- Xcode Console (wenn via Xcode gestartet)
