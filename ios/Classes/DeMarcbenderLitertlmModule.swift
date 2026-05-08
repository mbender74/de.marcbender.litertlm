//
//  DeMarcbenderLitertlmModule.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit



/**

 Titanium Swift Module Requirements
 ---

 1. Use the @objc annotation to expose your class to Objective-C (used by the Titanium core)
 2. Use the @objc annotation to expose your method to Objective-C as well.
 3. Method arguments always have the "[Any]" type, specifying a various number of arguments.
    Unwrap them like you would do in Swift, e.g. "guard let arguments = arguments, let message = arguments.first"
 4. You can use any public Titanium API like before, e.g. TiUtils. Remember the type safety of Swift, like Int vs Int32
    and NSString vs. String.

 */

@objc(DeMarcbenderLitertlmModule)
class DeMarcbenderLitertlmModule: TiModule {

  // MARK: - Properties

  /// Strong reference to keep Swift objects alive while proxies are used from JS
  private var _downloader: LiteRTLMModelDownloaderProxy?
  private var _engine: LMEngine?

  func moduleGUID() -> String {
    return "208537d4-6bc7-4c6c-abcc-71efc42ca465"
  }

  @objc
  override func moduleId() -> String! {
    return "de.marcbender.litertlm"
  }

  @objc
  override func startup() {
    super.startup()
    debugPrint("[DEBUG] TitaniumLiteRTLM module loaded")
  }

  // MARK: - Engine

  @objc(createEngine:)
  func createEngine(arguments: [Any]?) {
    guard let args = arguments, let firstArg = args.first as? [String: Any] else {
      throwException("Invalid arguments", subreason: "Expected a dictionary with 'modelPath' key", location: #function)
      return
    }

    let modelPath: String
    if let path = firstArg["modelPath"] as? String {
      modelPath = path
    } else if let path = firstArg["modelPath"] as? [String: Any] {
      modelPath = path["path"] as? String ?? "."
    } else {
      modelPath = "."
    }

    let backend: String = firstArg["backend"] as? String ?? "cpu"
    let maxTokens: Int32 = firstArg["maxTokens"] as? Int32 ?? 0
    let cacheDir: String? = firstArg["cacheDir"] as? String
    let benchmarkEnabled: Bool = firstArg["benchmarkEnabled"] as? Bool ?? false
    let logLevel: String = firstArg["logLevel"] as? String ?? "warning"

    var config = EngineConfiguration(modelPath: URL(fileURLWithPath: modelPath))
    switch backend {
    case "gpu": config = config.backend(.gpu)
    default: config = config.backend(.cpu)
    }
    if maxTokens > 0 { config = config.maxTokens(Int(maxTokens)) }
    if let cacheDir = cacheDir { config = config.cacheDirectory(URL(fileURLWithPath: cacheDir)) }
    if benchmarkEnabled { config = config.benchmarkEnabled(true) }
    switch logLevel {
    case "info": config = config.logLevel(.info)
    case "error": config = config.logLevel(.error)
    case "fatal": config = config.logLevel(.fatal)
    case "silent": config = config.logLevel(.silent)
    default: config = config.logLevel(.warning)
    }

    let engine = LMEngine(configuration: config)
    let proxy = LiteRTLMEngineProxy()
    proxy._status = "notLoaded"
    proxy.setEngine(engine)
    replaceValue(proxy, forKey: "engine", notification: false)

    debugPrint("[DEBUG] Engine created for model: \(modelPath)")
    fireEvent("enginecreated", with: ["engine": proxy])
  }

  @objc(createEngineWithConfig:)
  func createEngineWithConfig(arguments: [Any]?) {
    guard let args = arguments, let configArg = args.first as? LiteRTLMEngineConfiguration else {
      throwException("Invalid arguments", subreason: "Expected a LiteRTLMEngineConfiguration object", location: #function)
      return
    }

    do {
      let config = try configArg.toNative()
      let engine = LMEngine(configuration: config)
      let proxy = LiteRTLMEngineProxy()
      proxy._status = "notLoaded"
      proxy.setEngine(engine)
      replaceValue(proxy, forKey: "engine", notification: false)

      debugPrint("[DEBUG] Engine created with config")
      fireEvent("enginecreated", with: ["engine": proxy])
    } catch {
      throwException("Engine creation failed", subreason: error.localizedDescription, location: #function)
    }
  }

  // MARK: - Create Proxies

  @objc(createSessionProxy:)
  func createSessionProxy(arguments: [Any]?) {
    let proxy = LiteRTLMSessionProxy()
    proxy._isActive = false
    replaceValue(proxy, forKey: "session", notification: false)
  }

  @objc(createConversationProxy:)
  func createConversationProxy(arguments: [Any]?) {
    let proxy = LiteRTLMConversationProxy()
    proxy._isActive = false
    replaceValue(proxy, forKey: "conversation", notification: false)
  }

  @objc(createEngineConfigProxy:)
  func createEngineConfigProxy(arguments: [Any]?) {
    let proxy = LiteRTLMEngineConfiguration()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let modelPath = dict["modelPath"] as? String {
        proxy._modelPath = modelPath
      }
      if let backend = dict["backend"] as? String {
        proxy._primaryBackend = backend
      }
      if let maxTokens = dict["maxTokens"] as? Int32 {
        proxy._maxTokens = maxTokens
      }
      if let cacheDir = dict["cacheDir"] as? String {
        proxy._cacheDir = cacheDir
      }
      if let benchmark = dict["benchmarkEnabled"] as? Bool {
        proxy._isBenchmarkEnabled = benchmark
      }
      if let logLevel = dict["logLevel"] as? String {
        proxy._logLevel = logLevel
      }
      if let visionBackend = dict["visionBackend"] as? String {
        proxy._visionBackend = visionBackend
      }
      if let audioBackend = dict["audioBackend"] as? String {
        proxy._audioBackend = audioBackend
      }
    }
    replaceValue(proxy, forKey: "engineConfig", notification: false)
  }

  @objc(createSessionConfigProxy:)
  func createSessionConfigProxy(arguments: [Any]?) {
    let proxy = LiteRTLMSessionConfiguration()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let maxTokens = dict["maxOutputTokens"] as? Int32 {
        proxy._maxOutputTokens = maxTokens
      }
      if let samplerType = dict["samplerType"] as? String {
        proxy._samplerType = samplerType
      }
    }
    replaceValue(proxy, forKey: "sessionConfig", notification: false)
  }

  @objc(createConversationConfigProxy:)
  func createConversationConfigProxy(arguments: [Any]?) {
    let proxy = LiteRTLMConversationConfiguration()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let maxTokens = dict["maxOutputTokens"] as? Int32 {
        proxy._maxOutputTokens = maxTokens
      }
      if let samplerType = dict["samplerType"] as? String {
        proxy._samplerType = samplerType
      }
      if let mode = dict["toolExecutionMode"] as? String {
        proxy._toolExecutionMode = mode
      }
      if let maxDim = dict["maxImageDimension"] as? Int {
        proxy._maxImageDimension = maxDim
      }
      if let systemPrompt = dict["systemPrompt"] as? String {
        proxy._systemPrompt = systemPrompt
      }
    }
    replaceValue(proxy, forKey: "conversationConfig", notification: false)
  }

  @objc(createSamplerConfigProxy:)
  func createSamplerConfigProxy(arguments: [Any]?) {
    let proxy = LiteRTLMSamplerConfiguration()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let temperature = dict["temperature"] as? Double {
        proxy._temperature = Float(temperature)
      }
      if let topK = dict["topK"] as? Int32 {
        proxy._topK = topK
      }
      if let topP = dict["topP"] as? Double {
        proxy._topP = Float(topP)
      }
      if let seed = dict["seed"] as? Int32 {
        proxy._seed = seed
      }
      if let type = dict["samplerType"] as? String {
        proxy._samplerType = type
      }
    }
    replaceValue(proxy, forKey: "samplerConfig", notification: false)
  }

  @objc(createContentProxy:)
  func createContentProxy(arguments: [Any]?) {
    let proxy = LiteRTLMContent()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let type = dict["type"] as? String {
        proxy._type = type
      }
      if let text = dict["text"] as? String {
        proxy._text = text
      }
      if let imageData = dict["imageData"] as? Data {
        proxy._imageData = imageData
      }
      if let audioData = dict["audioData"] as? Data {
        proxy._audioData = audioData
      }
      if let format = dict["audioFormat"] as? String {
        proxy._audioFormat = format
      }
      if let maxDim = dict["maxDimension"] as? Int {
        proxy._maxDimension = maxDim
      }
    }
    replaceValue(proxy, forKey: "content", notification: false)
  }

  @objc(createMessageProxy:)
  func createMessageProxy(arguments: [Any]?) {
    let proxy = LiteRTLMMessage()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let role = dict["role"] as? String {
        proxy._role = role
      }
      if let contents = dict["contents"] as? [LiteRTLMContent] {
        proxy._contents = contents
      }
    }
    replaceValue(proxy, forKey: "message", notification: false)
  }

  @objc(createToolProxy:)
  func createToolProxy(arguments: [Any]?) {
    let proxy = LiteRTLMTool()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let name = dict["name"] as? String {
        proxy._name = name
      }
      if let desc = dict["description"] as? String {
        proxy._description = desc
      }
      if let params = dict["parameters"] as? [Any] {
        proxy._parameters = params
      }
    }
    replaceValue(proxy, forKey: "tool", notification: false)
  }

  // MARK: - Model Downloader

  @objc(createDownloader:)
  func createDownloader(arguments: [Any]?) -> Any? {
    let dir: String?
    if let args = arguments, let dict = args.first as? [String: Any] {
      dir = dict["modelsDirectory"] as? String
    } else {
      dir = nil
    }

    let proxy = LiteRTLMModelDownloaderProxy(modelsDirectory: dir)
    _downloader = proxy  // Keep Swift object alive
    replaceValue(proxy, forKey: "downloader", notification: false)
    debugPrint("[DEBUG] ModelDownloader created with directory: \(dir ?? "default")")
    return proxy
  }

  @objc(createModelInfo:)
  func createModelInfo(arguments: [Any]?) {
    let proxy = LiteRTLMModelInfo()
    if let args = arguments, let dict = args.first as? [String: Any] {
      if let name = dict["name"] as? String { proxy._name = name }
      if let displayName = dict["displayName"] as? String { proxy._displayName = displayName }
      if let url = dict["url"] as? String { proxy._url = url }
      if let expectedSize = dict["expectedSize"] as? Int64 { proxy._expectedSize = expectedSize }
      if let fileName = dict["fileName"] as? String { proxy._fileName = fileName }
    }
    replaceValue(proxy, forKey: "modelInfo", notification: false)
  }

  // MARK: - Utility Methods

  @objc(getVersion:)
  func getVersion(arguments: [Any]?) -> String {
    return "1.0.0"
  }

  @objc(example:)
  func example(arguments: [Any]?) -> String? {
    guard let arguments = arguments, let params = arguments.first as? [String: Any] else {
      return nil
    }
    return params["hello"] as? String
  }

  @objc public var exampleProp: String {
    get {
      return "Titanium rocks!"
    }
    set {
      self.replaceValue(newValue, forKey: "exampleProp", notification: false)
    }
  }
}
