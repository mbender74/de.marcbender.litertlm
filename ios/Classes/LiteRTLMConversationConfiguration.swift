//
//  LiteRTLMConversationConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMConversationConfiguration)
public class LiteRTLMConversationConfiguration: TiProxy {

  private var _maxOutputTokens: Int32 = 1024
  private var _samplerType: String = "balanced"
  private var _tools: [LiteRTLMTool] = []
  private var _toolExecutionMode: String = "automatic"
  private var _maxImageDimension: Int = 1024
  private var _systemPrompt: String?

  @objc public var maxOutputTokens: Int32 {
      get { return _maxOutputTokens }
      set { _maxOutputTokens = newValue; replaceValue(newValue, forKey: "maxOutputTokens", notification: false) }
  }

  @objc public var samplerType: String {
      get { return _samplerType }
      set { _samplerType = newValue; replaceValue(newValue, forKey: "samplerType", notification: false) }
  }

  @objc public var tools: [LiteRTLMTool] {
      get { return _tools }
      set { _tools = newValue; replaceValue(newValue, forKey: "tools", notification: false) }
  }

  @objc public var toolExecutionMode: String {
      get { return _toolExecutionMode }
      set { _toolExecutionMode = newValue; replaceValue(newValue, forKey: "toolExecutionMode", notification: false) }
  }

  @objc public var maxImageDimension: Int {
      get { return _maxImageDimension }
      set { _maxImageDimension = newValue; replaceValue(newValue, forKey: "maxImageDimension", notification: false) }
  }

  @objc public var systemPrompt: String? {
      get { return _systemPrompt }
      set { _systemPrompt = newValue; replaceValue(newValue, forKey: "systemPrompt", notification: false) }
  }

  @objc public var sampler: LiteRTLMSamplerConfiguration?

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public func toNative() -> ConversationConfiguration {
    var config = ConversationConfiguration()
    config = config.maxOutputTokens(_maxOutputTokens)
    config = config.maxImageDimension(_maxImageDimension)

    if let sampler = sampler {
      config = config.sampler(sampler.toNative())
    } else if _samplerType == "greedy" {
      config = config.sampler(.greedy)
    } else if _samplerType == "creative" {
      config = config.sampler(.creative)
    } else {
      config = config.sampler(.balanced)
    }

    if _toolExecutionMode == "manual" {
      config = config.toolExecution(.manual)
    } else {
      config = config.toolExecution(.automatic)
    }

    if let prompt = _systemPrompt {
      config = config.systemPrompt(prompt)
    }

    let nativeTools = _tools.map { $0.toNative() }
    if !nativeTools.isEmpty {
      config = config.tools(nativeTools)
    }

    return config
  }
}
