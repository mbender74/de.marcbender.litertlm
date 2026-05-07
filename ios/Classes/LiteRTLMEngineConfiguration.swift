//
//  LiteRTLMEngineConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMEngineConfiguration)
public class LiteRTLMEngineConfiguration: TiProxy {

  private var _modelPath: String = ""
  private var _primaryBackend: String = "cpu"
  private var _visionBackend: String?
  private var _audioBackend: String?
  private var _maxTokens: Int32?
  private var _cacheDir: String?
  private var _isBenchmarkEnabled: Bool = false
  private var _logLevel: String = "warning"

  @objc public private(set) var modelPath: String = ""

  @objc public func getModelPath() -> String {
    return _modelPath
  }

  @objc public func setModelPath(_ value: String) {
    _modelPath = value
  }

  @objc public private(set) var primaryBackend: String = "cpu"

  @objc public func getPrimaryBackend() -> String {
    return _primaryBackend
  }

  @objc public func setPrimaryBackend(_ value: String) {
    _primaryBackend = value
  }

  @objc public private(set) var visionBackend: String?

  @objc public func getVisionBackend() -> String? {
    return _visionBackend
  }

  @objc public func setVisionBackend(_ value: String?) {
    _visionBackend = value
  }

  @objc public private(set) var audioBackend: String?

  @objc public func getAudioBackend() -> String? {
    return _audioBackend
  }

  @objc public func setAudioBackend(_ value: String?) {
    _audioBackend = value
  }

  @objc public private(set) var maxTokens: Int32?

  @objc public func getMaxTokens() -> Int32? {
    return _maxTokens
  }

  @objc public func setMaxTokens(_ value: Int32?) {
    _maxTokens = value
  }

  @objc public private(set) var cacheDir: String?

  @objc public func getCacheDir() -> String? {
    return _cacheDir
  }

  @objc public func setCacheDir(_ value: String?) {
    _cacheDir = value
  }

  @objc public private(set) var isBenchmarkEnabled: Bool = false

  @objc public func getIsBenchmarkEnabled() -> Bool {
    return _isBenchmarkEnabled
  }

  @objc public func setIsBenchmarkEnabled(_ value: Bool) {
    _isBenchmarkEnabled = value
  }

  @objc public private(set) var logLevel: String = "warning"

  @objc public func getLogLevel() -> String {
    return _logLevel
  }

  @objc public func setLogLevel(_ value: String) {
    _logLevel = value
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public func toNative() throws -> EngineConfiguration {
    var config = EngineConfiguration(modelPath: URL(fileURLWithPath: _modelPath))

    switch _primaryBackend {
    case "gpu": config = config.backend(.gpu)
    default: config = config.backend(.cpu)
    }

    if let visionBackend = _visionBackend {
      switch visionBackend {
      case "gpu": config = config.visionBackend(.gpu)
      default: break
      }
    }

    if let audioBackend = _audioBackend {
      switch audioBackend {
      case "gpu": config = config.audioBackend(.gpu)
      default: break
      }
    }

    if let maxTokens = _maxTokens {
      config = config.maxTokens(Int(maxTokens))
    }

    if let cacheDir = _cacheDir {
      config = config.cacheDirectory(URL(fileURLWithPath: cacheDir))
    }

    if _isBenchmarkEnabled {
      config = config.benchmarkEnabled(true)
    }

    switch _logLevel {
    case "info": config = config.logLevel(.info)
    case "error": config = config.logLevel(.error)
    case "fatal": config = config.logLevel(.fatal)
    case "silent": config = config.logLevel(.silent)
    default: config = config.logLevel(.warning)
    }

    return config
  }
}
