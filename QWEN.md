# TitaniumLiteRTLM – Qwen Code Session Context

## Projekt-Übersicht

Titanium iOS-Modul (`de.marcbender.litertlm`) das Google LiteRTLM-Swift-SDK umschließt für On-Device LLM-Inferenz.

**Wichtige Pfade:**
- **Projekt-Root:** `/Users/marcbender/TitaniumLiteRTLM`
- **Modul-Quellcode:** `ios/Classes/`
- **Test-App:** `/Users/marcbender/example/testApp`
- **Referenz-Module:**
  - `/Users/marcbender/Downloads/ti.circularprogress-main` (funktionierendes TiProxy-Beispiel)
  - `/Users/marcbender/Downloads/ti.cardscanner-main` (Facade-Pattern für externe Swift-Typen)

## Git Identity

```
Name: mbender74
Email: marc_bender@icloud.com
```

## Build & Install

```bash
# Modul bauen (Simulator + Device)
cd /Users/marcbender/TitaniumLiteRTLM/ios && ti build -p ios --build-only

# In testApp installieren
cd /Users/marcbender/example/testApp && rm -rf modules/iphone/de.marcbender.litertlm && \
  unzip -o /Users/marcbender/TitaniumLiteRTLM/ios/dist/de.marcbender.litertlm-iphone-1.0.0.zip -d modules/iphone/

# testApp kompilieren (Simulator)
ti build --project-dir "/Users/marcbender/example/testApp" --log-level trace --platform ios --color \
  --no-prompt --target simulator --device-id EF7ADE41-4058-4E56-8344-F6164B60D53B --sdk "13.2.0.GA"
```

## Debugging

```bash
# Module-Logs (vor App-Start in separatem Terminal)
log stream --predicate 'message contains "[DEBUG]"'
```

## Titanium Swift Module Patterns

### TiModule (Hauptmodul)

```swift
@objc(ModuleName)
class ModuleName: TiModule {
  // Static ref um Modul am Leben zu halten
  static var _moduleRef: AnyObject?
  
  // Strong refs um Swift-Objekte am Leben zu halten
  private var _nativeDownloader: ModelDownloader?
  
  override func startup() {
    Self._moduleRef = self  // Modul am Leben halten
    super.startup()
  }
  
  // JS-callbare Methoden
  @objc(methodName:)
  func methodName(arguments: [Any]?) -> Any? {
    guard let params = arguments?.first as? [String: Any] else { return nil }
    // ...
  }
}
```

### TiProxy Subklassen

**Kritisch: Kein Import externer Swift-Frameworks!** Externe Typen in `@objc`-Signaturen triggern Swift Metadata Initialization die crascht.

```swift
@objc(ProxyName)
public class ProxyName: TiProxy {
  // ✅ Sichere Property-Typen
  private var _stringProp: NSString?
  @objc public var numberProp: NSNumber
  
  // ✅ Init – nur super, keine externen Typen
  override init() { super.init() }
  
  override public func _init(withProperties properties: [AnyHashable : Any]!) {
    super._init(withProperties: properties)
    // Properties aus JS extrahieren
  }
  
  // ✅ Alle Parameter als Any?
  @objc public func someMethod(_ arg: Any?) -> Bool {
    // Delegate ins Modul für CLiteRTLM-Arbeit
    module().delegateMethod(with: arg, proxy: self)
  }
  
  private func module() -> MyModule? {
    return MyModule._moduleRef as? MyModule
  }
}
```

### Sichere vs. unsichere Property-Typen

| Typ | Status |
|-----|--------|
| `NSString?`, `NSNumber`, `Bool`, `String`, `Int` | ✅ |
| `AnyObject?` (mit `as?` Cast) | ✅ |
| `ModelDownloader?` (externer Swift-Typ) | ❌ Crashed |
| `LiteRTLMModelInfo` (externer Swift-Typ als @objc-Param) | ❌ Crashed |

### JS-Argumente-Handling

JS-Objekte kommen als `NSArray` – erstens Element ist das params dict:

```swift
// In @objc-Methoden des Moduls
guard let params = arguments?.first as? [String: Any] else { return nil }

// In Proxy-Delegation (von Modul aufgerufen)
let args = modelInfo as? [Any] ?? []
let params = args.first as? [AnyHashable: Any]
```

## Architektur: Facade-Pattern

**Problem:** TiProxy + CLiteRTLM Import = SIGSEGV bei `swift_retain`

**Lösung:** Proxy kennt keine externen Typen, delegiert alles ins Modul:

```
JS → LiteRTLMModelDownloaderProxy (kein externer Import)
     ↓ delegateDownload(with: proxy:)
   DeMarcbenderLitertlmModule (CLiteRTLM importiert)
     ↓
   ModelDownloader (@Observable, macht URLSession-Downloads)
```

## ModelDownloader Progress Reporting

`ModelDownloader` ist `@Observable` (kein Callback-Parameter). Progress via Polling:

```swift
private func pollDownload(proxy: LiteRTLMModelDownloaderProxy, work: @escaping () async -> Void) async {
  let dl = self.downloader()
  let pollTask = Task.detached(priority: .utility) {
    while true {
      try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
      switch dl.state {
      case .downloading: proxy.fireEvent("downloadprogress", with: [...])
      case .completed:   proxy.fireEvent("downloadcomplete", with: [...])
      case .failed(let msg): proxy.fireEvent("downloaderror", with: ["message": msg])
      default: break
      }
    }
  }
  await work()
  pollTask.cancel()
}
```

## Logging

Verwende `NSLog("[DEBUG] ...")` für alle diagnostischen Ausgaben.

## Kritische Titanium-Swift-Pattern

### NSArray-Wrapper für TiProxy-Parameter
Titanium wrapp't TiProxy-Objekte die von JS an Swift übergeben werden in `__NSArrayM`.
Jede `@objc`-Methode die einen TiProxy erwartet muss dies entpacken:

```swift
@objc func myMethod(_ arg: Any) {
  // Entpacken
  let proxy: MyProxy
  if let arr = arg as? [Any], let first = arr.first as? MyProxy {
    proxy = first
  } else if let p = arg as? MyProxy {
    proxy = p
  } else {
    return // Invalid type
  }
  // Werte SOFORT kopieren bevor proxy vom JS GC befreit wird!
}
```

### Event-Fire auf dem Modul, nicht auf dem Proxy
JS-Listener die auf `litertlm.addEventListener(...)` registriert sind, hören auf das **Modul**.
Events müssen vom Modul gefeuert werden, nicht vom Proxy:

```swift
// FALSCH: feuert auf dem engine Proxy (JS hört nicht zu)
self.fireEvent("conversationcreated", with: [...])

// RICHTIG: feuert auf dem Modul (JS hört hier zu)
if let module = DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule {
  module.fireEvent("conversationcreated", with: [...])
}
```

### replaceValue() für Proxy-Registrierung
Bevor ein Proxy an JS übergeben werden kann (per Event oder als Property) muss er bei
Titaniums JS-Bridge registriert werden:

```swift
let proxy = LiteRTLMConversationProxy()
proxy._conversation = conversation
self.replaceValue(proxy, forKey: "conversation", notification: false)  // Pflicht!
module.fireEvent("conversationcreated", with: ["conversation": proxy])
```

### LiteRTLM NULL-Config für Conversation
Die LiteRTLM-Version in diesem Projekt unterstützt `litert_lm_conversation_create()` nur
mit NULL-Config. Die builder-style Config-Setter funktionieren nicht:

```swift
// FUNKTIONIERT: NULL config
let cConversation = litert_lm_conversation_create(engine, nil)

// FUNKTIONIERT NICHT: builder-style config (gibt NULL zurück)
let convConfig = litert_lm_conversation_config_create()
litert_lm_conversation_config_set_session_config(convConfig, sessionConfig)
let cConversation = litert_lm_conversation_create(engine, convConfig) // ← NULL!
```

Custom-Parameter (maxOutputTokens, sampler, systemPrompt) werden daher nicht angewendet.

### Streaming-Events
`sendStream()` feuert folgende Events auf dem **conversation Proxy** (nicht Modul):

| Event | Payload | Bedeutung |
|-------|---------|-----------|
| `streamstart` | `{}` | Stream beginnt |
| `token` | `{ token: "Text" }` | Pro Token (inkrementell) |
| `streamcomplete` | `{}` | Stream abgeschlossen |
| `streamend` | `{}` | Stream beendet |
| `streamerror` | `{ message: "..." }` | Fehler |

JS muss `setupStreamListeners()` nach `conversationcreated` aufrufen um die Listener zu registrieren.

## Dateien im Überblick

```
ios/Classes/
├── DeMarcbenderLitertlmModule.swift       # Haupt-Modul (TiModule) – CLiteRTLM importiert
├── LiteRTLMModelDownloaderProxy.swift     # Downloader Proxy (kein externer Import)
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
    ├── ModelDownloader.swift               # @Observable, URLSession-Downloads
    ├── ModelInfo.swift                     # Swift struct
    └── DownloadState.swift                 # enum: idle, downloading, paused, completed, failed
```

## Aktueller Status

### ✅ Funktioniert
- Modul-Startup, `createDownloader()`, `isDownloaded()`, `download()`
- Progress-Events: `downloadprogress`, `downloadcomplete`, `downloaderror`
- Engine-Initialisierung, `createEngineWithConfig()`
- Conversation-Erstellung, `createConversationWithConfig()`
- **Streaming**: `sendStream()` mit Token-Events, vollständige Antwort
- Events korrekt geroutet (Module vs. Proxy)

### 🔧 TODO
- [ ] Tool Calling, Multimodale Eingabe
- [ ] LiteRTLM updaten für builder-style config support (oder Session-API als Fallback)

### ⚠️ Bekannte Probleme
- `LiteRTLMEngineProxy` hält `LMEngine` direkt (externer Typ) – muss ggf. refactored werden
- `LiteRTLMConversationProxy` hält `Conversation` direkt – muss ggf. refactored werden
- Custom-Config-Parameter werden für Conversations nicht angewendet (NULL-Config Limitierung)
