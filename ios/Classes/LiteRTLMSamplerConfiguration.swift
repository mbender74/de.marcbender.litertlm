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

  @objc public private(set) var temperature: Float = 0.7

  @objc public func getTemperature() -> Double {
    return Double(_temperature)
  }

  @objc public func setTemperature(_ value: Double) {
    _temperature = Float(value)
  }

  @objc public private(set) var topK: Int32 = 40

  @objc public func getTopK() -> Int32 {
    return _topK
  }

  @objc public func setTopK(_ value: Int32) {
    _topK = value
  }

  @objc public private(set) var topP: Float = 0.95

  @objc public func getTopP() -> Double {
    return Double(_topP)
  }

  @objc public func setTopP(_ value: Double) {
    _topP = Float(value)
  }

  @objc public private(set) var seed: Int32 = -1

  @objc public func getSeed() -> Int32 {
    return _seed
  }

  @objc public func setSeed(_ value: Int32) {
    _seed = value
  }

  @objc public private(set) var samplerType: String = "topK"

  @objc public func getSamplerType() -> String {
    return _samplerType
  }

  @objc public func setSamplerType(_ value: String) {
    _samplerType = value
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
