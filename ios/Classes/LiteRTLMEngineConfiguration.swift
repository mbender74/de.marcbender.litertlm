//
//  LiteRTLMEngineConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMEngineConfiguration)
public class LiteRTLMEngineConfiguration: TiProxy {

  internal var _modelPath: String = ""
  internal var _primaryBackend: String = "cpu"
  internal var _visionBackend: String?
  internal var _audioBackend: String?
  internal var _maxTokens: Int32?
  internal var _cacheDir: String?
  internal var _isBenchmarkEnabled: Bool = false
  internal var _logLevel: String = "warning"

  @objc public var modelPath: String {
      get { return _modelPath }
      set { _modelPath = newValue; replaceValue(newValue, forKey: "modelPath", notification: false) }
  }

  @objc public var primaryBackend: String {
      get { return _primaryBackend }
      set { _primaryBackend = newValue; replaceValue(newValue, forKey: "primaryBackend", notification: false) }
  }

  @objc public var visionBackend: String? {
      get { return _visionBackend }
      set { _visionBackend = newValue; replaceValue(newValue, forKey: "visionBackend", notification: false) }
  }

  @objc public var audioBackend: String? {
      get { return _audioBackend }
      set { _audioBackend = newValue; replaceValue(newValue, forKey: "audioBackend", notification: false) }
  }

  public var maxTokens: Int32? {
      get { return _maxTokens }
      set { _maxTokens = newValue; replaceValue(newValue, forKey: "maxTokens", notification: false) }
  }

  @objc public var cacheDir: String? {
      get { return _cacheDir }
      set { _cacheDir = newValue; replaceValue(newValue, forKey: "cacheDir", notification: false) }
  }

  @objc public var isBenchmarkEnabled: Bool {
      get { return _isBenchmarkEnabled }
      set { _isBenchmarkEnabled = newValue; replaceValue(newValue, forKey: "isBenchmarkEnabled", notification: false) }
  }

  @objc public var logLevel: String {
      get { return _logLevel }
      set { _logLevel = newValue; replaceValue(newValue, forKey: "logLevel", notification: false) }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

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
