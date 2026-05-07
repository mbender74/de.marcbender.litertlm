//
//  LiteRTLMSessionConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMSessionConfiguration)
public class LiteRTLMSessionConfiguration: TiProxy {

  private var _maxOutputTokens: Int32 = 512
  private var _samplerType: String = "balanced"

  @objc public var maxOutputTokens: Int32 {
      get { return _maxOutputTokens }
      set { _maxOutputTokens = newValue; replaceValue(newValue, forKey: "maxOutputTokens", notification: false) }
  }

  @objc public var samplerType: String {
      get { return _samplerType }
      set { _samplerType = newValue; replaceValue(newValue, forKey: "samplerType", notification: false) }
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
