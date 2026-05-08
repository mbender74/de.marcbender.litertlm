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

// MARK: - Global Module Reference

/// Static reference to keep the MODULE alive for the entire app lifetime
@objc(DeMarcbenderLitertlmModule)
class DeMarcbenderLitertlmModule: TiModule {

  // MARK: - Properties

  /// Strong reference to keep the MODULE alive for the entire app lifetime
  static var _moduleRef: AnyObject?

  /// Strong reference to keep Swift objects alive while proxies are used from JS
  private var _downloader: AnyObject?
  private var _engine: LMEngine?

  override init() {
    NSLog("[DEBUG] init() CALLED")
    super.init()
    NSLog("[DEBUG] init() SUPER.INIT DONE")
  }

  required init?(arguments: [Any]? = nil) {
    NSLog("[DEBUG] init?(arguments:) CALLED")
    super.init()
    NSLog("[DEBUG] init?(arguments:) SUPER.INIT DONE")
  }

  func moduleGUID() -> String {
    NSLog("[DEBUG] moduleGUID() called")
    return "208537d4-6bc7-4c6c-abcc-71efc42ca465"
  }

  override func moduleId() -> String! {
    NSLog("[DEBUG] moduleId() called")
    return "de.marcbender.litertlm"
  }

  override func startup() {
    NSLog("[DEBUG] MODULE STARTUP - setting _moduleRef")
    Self._moduleRef = self
    NSLog("[DEBUG] _moduleRef = \(Self._moduleRef != nil ? "SET" : "nil")")
    super.startup()
    NSLog("[DEBUG] \(self) loaded")
    NSLog("[DEBUG] MODULE STARTUP DONE")
  }

  deinit {
    NSLog("[DEBUG] MODULE DEINIT")
  }

  // MARK: - Engine

  @objc(createEngine:)
  func createEngine(arguments: [Any]?) {
    NSLog("[DEBUG] createEngine() CALLED")
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

    NSLog("[DEBUG] About to fire enginecreated event")
    fireEvent("enginecreated", with: ["engine": proxy])
    NSLog("[DEBUG] enginecreated event fired")
  }

  @objc(createEngineWithConfig:)
  func createEngineWithConfig(arguments: [Any]?) {
    NSLog("[DEBUG] createEngineWithConfig() CALLED")
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

      NSLog("[DEBUG] About to fire enginecreated event (config)")
      fireEvent("enginecreated", with: ["engine": proxy])
      NSLog("[DEBUG] enginecreated event fired (config)")
    } catch {
      throwException("Engine creation failed", subreason: error.localizedDescription, location: #function)
    }
  }

  // MARK: - Create Proxies

  @objc(createSessionProxy:)
  func createSessionProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createSessionProxy() CALLED")
    let proxy = LiteRTLMSessionProxy()
    proxy._isActive = false
    replaceValue(proxy, forKey: "session", notification: false)
  }

  @objc(createConversationProxy:)
  func createConversationProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createConversationProxy() CALLED")
    let proxy = LiteRTLMConversationProxy()
    proxy._isActive = false
    replaceValue(proxy, forKey: "conversation", notification: false)
  }

  @objc(createEngineConfigProxy:)
  func createEngineConfigProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createEngineConfigProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMEngineConfiguration()
    if let modelPath = params["modelPath"] as? String {
      proxy._modelPath = modelPath
    }
    if let backend = params["backend"] as? String {
      proxy._primaryBackend = backend
    }
    if let maxTokens = params["maxTokens"] as? Int32 {
      proxy._maxTokens = maxTokens
    }
    if let cacheDir = params["cacheDir"] as? String {
      proxy._cacheDir = cacheDir
    }
    if let benchmark = params["benchmarkEnabled"] as? Bool {
      proxy._isBenchmarkEnabled = benchmark
    }
    if let logLevel = params["logLevel"] as? String {
      proxy._logLevel = logLevel
    }
    if let visionBackend = params["visionBackend"] as? String {
      proxy._visionBackend = visionBackend
    }
    if let audioBackend = params["audioBackend"] as? String {
      proxy._audioBackend = audioBackend
    }
    replaceValue(proxy, forKey: "engineConfig", notification: false)
  }

  @objc(createSessionConfigProxy:)
  func createSessionConfigProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createSessionConfigProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMSessionConfiguration()
    if let maxTokens = params["maxOutputTokens"] as? Int32 {
      proxy._maxOutputTokens = maxTokens
    }
    if let samplerType = params["samplerType"] as? String {
      proxy._samplerType = samplerType
    }
    replaceValue(proxy, forKey: "sessionConfig", notification: false)
  }

  @objc(createConversationConfigProxy:)
  func createConversationConfigProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createConversationConfigProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMConversationConfiguration()
    if let maxTokens = params["maxOutputTokens"] as? Int32 {
      proxy._maxOutputTokens = maxTokens
    }
    if let samplerType = params["samplerType"] as? String {
      proxy._samplerType = samplerType
    }
    if let mode = params["toolExecutionMode"] as? String {
      proxy._toolExecutionMode = mode
    }
    if let maxDim = params["maxImageDimension"] as? Int {
      proxy._maxImageDimension = maxDim
    }
    if let systemPrompt = params["systemPrompt"] as? String {
      proxy._systemPrompt = systemPrompt
    }
    replaceValue(proxy, forKey: "conversationConfig", notification: false)
  }

  @objc(createSamplerConfigProxy:)
  func createSamplerConfigProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createSamplerConfigProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMSamplerConfiguration()
    if let temperature = params["temperature"] as? Double {
      proxy._temperature = Float(temperature)
    }
    if let topK = params["topK"] as? Int32 {
      proxy._topK = topK
    }
    if let topP = params["topP"] as? Double {
      proxy._topP = Float(topP)
    }
    if let seed = params["seed"] as? Int32 {
      proxy._seed = seed
    }
    if let type = params["samplerType"] as? String {
      proxy._samplerType = type
    }
    replaceValue(proxy, forKey: "samplerConfig", notification: false)
  }

  @objc(createContentProxy:)
  func createContentProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createContentProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMContent()
    if let type = params["type"] as? String {
      proxy._type = type
    }
    if let text = params["text"] as? String {
      proxy._text = text
    }
    if let imageData = params["imageData"] as? Data {
      proxy._imageData = imageData
    }
    if let audioData = params["audioData"] as? Data {
      proxy._audioData = audioData
    }
    if let format = params["audioFormat"] as? String {
      proxy._audioFormat = format
    }
    if let maxDim = params["maxDimension"] as? Int {
      proxy._maxDimension = maxDim
    }
    replaceValue(proxy, forKey: "content", notification: false)
  }

  @objc(createMessageProxy:)
  func createMessageProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createMessageProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMMessage()
    if let role = params["role"] as? String {
      proxy._role = role
    }
    if let contents = params["contents"] as? [LiteRTLMContent] {
      proxy._contents = contents
    }
    replaceValue(proxy, forKey: "message", notification: false)
  }

  @objc(createToolProxy:)
  func createToolProxy(arguments: [Any]?) {
    NSLog("[DEBUG] createToolProxy() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMTool()
    if let name = params["name"] as? String {
      proxy._name = name
    }
    if let desc = params["description"] as? String {
      proxy._description = desc
    }
    if let parameters = params["parameters"] as? [Any] {
      proxy._parameters = parameters
    }
    replaceValue(proxy, forKey: "tool", notification: false)
  }

  // MARK: - Model Downloader

  @objc(createDownloader:)
  func createDownloader(arguments: [Any]?) -> Any? {
    NSLog("[DEBUG] createDownloader() CALLED")
    guard let params = arguments?.first as? [String: Any] else {
      NSLog("[DEBUG] createDownloader: invalid params")
      return nil
    }

    let dir: String? = params["modelsDirectory"] as? String
    NSLog("[DEBUG] createDownloader: modelsDirectory = \(dir ?? "nil")")

    let proxy = LiteRTLMModelDownloaderProxy()
    proxy._init(withProperties: ["modelsDirectory": dir as Any])
    _downloader = proxy
    replaceValue(proxy, forKey: "downloader", notification: false)
    NSLog("[DEBUG] ModelDownloader created with directory: \(dir ?? "default")")
    return proxy
  }

  @objc(createModelInfo:)
  func createModelInfo(arguments: [Any]?) {
    NSLog("[DEBUG] createModelInfo() CALLED")
    guard let params = arguments?.first as? [String: Any] else { return }
    let proxy = LiteRTLMModelInfo()
    if let name = params["name"] as? String { proxy._name = name }
    if let displayName = params["displayName"] as? String { proxy._displayName = displayName }
    if let url = params["url"] as? String { proxy._url = url }
    if let expectedSize = params["expectedSize"] as? Int64 { proxy._expectedSize = expectedSize }
    if let fileName = params["fileName"] as? String { proxy._fileName = fileName }
    replaceValue(proxy, forKey: "modelInfo", notification: false)
  }

  // MARK: - Utility Methods

  @objc(getVersion:)
  func getVersion(arguments: [Any]?) -> String {
    NSLog("[DEBUG] getVersion() CALLED")
    return "1.0.0"
  }

  @objc(example:)
  func example(arguments: [Any]?) -> String? {
    NSLog("[DEBUG] example() CALLED")
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

  // MARK: - Downloader Delegation (ModelDownloader lives here, not in proxy)

  private var _nativeDownloader: ModelDownloader?

  private func downloader() -> ModelDownloader {
    if let dl = _nativeDownloader { return dl }
    let proxy = _downloader as? LiteRTLMModelDownloaderProxy
    let dir = proxy?.modelsDirectory.map { URL(fileURLWithPath: $0) }
    let dl = ModelDownloader(modelsDirectory: dir)
    _nativeDownloader = dl
    return dl
  }

  func delegateDownload(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) {
    // Titanium passes args as NSArray – first element is the actual dict
    let args = modelInfo as? [Any] ?? []
    let params = args.first as? [AnyHashable: Any]
    NSLog("[DEBUG] delegateDownload: args.count=\(args.count), params=\(params ?? [:])")
    guard let params = params else {
      NSLog("[DEBUG] delegateDownload: cannot extract params from args")
      return
    }
    let urlStr = params["url"] as? String ?? ""
    let fileName = params["fileName"] as? String
    let expectedSize = (params["expectedSize"] as? NSNumber).map { $0.int64Value }
    NSLog("[DEBUG] delegateDownload: url=\(urlStr) fileName=\(fileName ?? "nil") expectedSize=\(expectedSize?.description ?? "nil")")

    guard let url = URL(string: urlStr) else {
      NSLog("[DEBUG] delegateDownload: invalid URL")
      proxy.fireEvent("downloaderror", with: ["message": "Invalid URL: \(urlStr)"])
      return
    }

    NSLog("[DEBUG] delegateDownload: starting Task...")
    Task {
      NSLog("[DEBUG] delegateDownload: inside Task, calling pollDownload")
      await self.pollDownload(proxy: proxy) {
        NSLog("[DEBUG] delegateDownload: calling ModelDownloader.download")
        await self.downloader().download(from: url, fileName: fileName, expectedSize: expectedSize)
        NSLog("[DEBUG] delegateDownload: ModelDownloader.download returned")
      }
      NSLog("[DEBUG] delegateDownload: pollDownload returned")
    }
  }

  func delegateDownloadFrom(url urlStr: String, fileName: String?, expectedSize: NSNumber?, proxy: LiteRTLMModelDownloaderProxy) {
    guard let url = URL(string: urlStr) else {
      proxy.fireEvent("downloaderror", with: ["message": "Invalid URL"])
      return
    }
    let size: Int64? = expectedSize?.int64Value

    Task {
      await self.pollDownload(proxy: proxy) {
        await self.downloader().download(from: url, fileName: fileName, expectedSize: size)
      }
    }
  }

  func delegatePauseDownload(proxy: LiteRTLMModelDownloaderProxy) {
    self.downloader().pause()
  }

  func delegateCancelDownload(proxy: LiteRTLMModelDownloaderProxy) {
    self.downloader().cancel()
  }

  func delegateIsDownloaded(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) -> Bool {
    let args = modelInfo as? [Any] ?? []
    guard let params = args.first as? [AnyHashable: Any] else { return false }
    let fileName = params["fileName"] as? String ?? ""
    return self.downloader().isDownloaded(fileName: fileName)
  }

  func delegateModelPath(for modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) -> String? {
    let args = modelInfo as? [Any] ?? []
    guard let params = args.first as? [AnyHashable: Any] else { return nil }
    let fileName = params["fileName"] as? String ?? ""
    return self.downloader().modelPath(fileName: fileName)?.path
  }

  func delegateDeleteModel(with modelInfo: Any?, proxy: LiteRTLMModelDownloaderProxy) {
    let args = modelInfo as? [Any] ?? []
    guard let params = args.first as? [AnyHashable: Any] else { return }
    let fileName = params["fileName"] as? String ?? ""
    try? self.downloader().deleteModel(fileName: fileName)
  }

  func delegateDeleteModel(fileName: String, proxy: LiteRTLMModelDownloaderProxy) {
    try? self.downloader().deleteModel(fileName: fileName)
  }

  // MARK: - Progress Polling (ModelDownloader is @Observable, no callback param)

  private func pollDownload(proxy: LiteRTLMModelDownloaderProxy, work: @escaping () async -> Void) async {
    let dl = self.downloader()
    let pollTask = Task.detached(priority: .utility) {
      while true {
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        let state = dl.state
        let progress = dl.progress
        let downloaded = dl.downloadedBytes
        let total = dl.totalBytes ?? 0

        switch state {
        case .downloading:
          DispatchQueue.main.async {
            proxy.fireEvent("downloadprogress", with: [
              "progress": progress,
              "bytesDownloaded": downloaded,
              "totalBytes": total
            ])
          }
        case .completed:
          DispatchQueue.main.async {
            proxy.fireEvent("downloadcomplete", with: ["fileName": dl.modelsDirectory.lastPathComponent])
          }
          return
        case .failed(let message):
          DispatchQueue.main.async {
            proxy.fireEvent("downloaderror", with: ["message": message])
          }
          return
        default:
          break
        }
      }
    }

    await work()
    pollTask.cancel()
  }
}
