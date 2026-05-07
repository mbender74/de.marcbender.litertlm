//
//  LiteRTLMSamplerConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMSamplerConfiguration)
public class LiteRTLMSamplerConfiguration: TiProxy {

  private var _temperature: Float = 0.7
  private var _topK: Int32 = 40
  private var _topP: Float = 0.95
  private var _seed: Int32 = -1
  private var _samplerType: String = "topK"

  @objc public var temperature: Float {
      get { return _temperature }
      set { _temperature = newValue; replaceValue(newValue, forKey: "temperature", notification: false) }
  }

  @objc public var topK: Int32 {
      get { return _topK }
      set { _topK = newValue; replaceValue(newValue, forKey: "topK", notification: false) }
  }

  @objc public var topP: Float {
      get { return _topP }
      set { _topP = newValue; replaceValue(newValue, forKey: "topP", notification: false) }
  }

  @objc public var seed: Int32 {
      get { return _seed }
      set { _seed = newValue; replaceValue(newValue, forKey: "seed", notification: false) }
  }

  @objc public var samplerType: String {
      get { return _samplerType }
      set { _samplerType = newValue; replaceValue(newValue, forKey: "samplerType", notification: false) }
  }

  @objc
  public static func greedy() -> LiteRTLMSamplerConfiguration {
    let config = LiteRTLMSamplerConfiguration(application: .getInstance())
    config._temperature = 0.0
    config._topK = 1
    config._topP = 1.0
    config._samplerType = "greedy"
    return config
  }

  @objc
  public static func balanced() -> LiteRTLMSamplerConfiguration {
    let config = LiteRTLMSamplerConfiguration(application: .getInstance())
    config._temperature = 0.7
    config._topK = 40
    config._topP = 0.95
    config._samplerType = "topK"
    return config
  }

  @objc
  public static func creative() -> LiteRTLMSamplerConfiguration {
    let config = LiteRTLMSamplerConfiguration(application: .getInstance())
    config._temperature = 1.0
    config._topK = 100
    config._topP = 0.98
    config._samplerType = "topP"
    return config
  }

  @objc
  public func toNative() -> SamplerConfiguration {
    var type: SamplerConfiguration.SamplerType = .topK
    switch _samplerType {
    case "topP": type = .topP
    case "greedy": type = .greedy
    default: type = .topK
    }
    return SamplerConfiguration(
      temperature: _temperature,
      topK: _topK,
      topP: _topP,
      seed: _seed,
      samplerType: type
    )
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }
}
