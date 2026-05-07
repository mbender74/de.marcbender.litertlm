//
//  LiteRTLMSessionConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMSessionConfiguration)
public class LiteRTLMSessionConfiguration: TiProxy {

  private var _maxOutputTokens: Int32 = 512
  private var _samplerType: String = "balanced"

  @objc public private(set) var maxOutputTokens: Int32 = 512

  @objc public func getMaxOutputTokens() -> Int32 {
    return _maxOutputTokens
  }

  @objc public func setMaxOutputTokens(_ value: Int32) {
    _maxOutputTokens = value
  }

  @objc public private(set) var samplerType: String = "balanced"

  @objc public func getSamplerType() -> String {
    return _samplerType
  }

  @objc public func setSamplerType(_ value: String) {
    _samplerType = value
  }

  @objc public var sampler: LiteRTLMSamplerConfiguration?

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public func toNative() -> SessionConfiguration {
    var config = SessionConfiguration()
    config = config.maxOutputTokens(_maxOutputTokens)

    if let sampler = sampler {
      config = config.sampler(sampler.toNative())
    } else if _samplerType == "greedy" {
      config = config.sampler(.greedy)
    } else if _samplerType == "creative" {
      config = config.sampler(.creative)
    } else {
      config = config.sampler(.balanced)
    }

    return config
  }
}
