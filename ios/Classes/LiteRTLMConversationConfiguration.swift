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

  @objc public private(set) var maxOutputTokens: Int32 = 1024

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

  @objc public private(set) var tools: [LiteRTLMTool] = []

  @objc public func getTools() -> [LiteRTLMTool] {
    return _tools
  }

  @objc public func setTools(_ value: [LiteRTLMTool]) {
    _tools = value
  }

  @objc public private(set) var toolExecutionMode: String = "automatic"

  @objc public func getToolExecutionMode() -> String {
    return _toolExecutionMode
  }

  @objc public func setToolExecutionMode(_ value: String) {
    _toolExecutionMode = value
  }

  @objc public private(set) var maxImageDimension: Int = 1024

  @objc public func getMaxImageDimension() -> Int {
    return _maxImageDimension
  }

  @objc public func setMaxImageDimension(_ value: Int) {
    _maxImageDimension = value
  }

  @objc public private(set) var systemPrompt: String?

  @objc public func getSystemPrompt() -> String? {
    return _systemPrompt
  }

  @objc public func setSystemPrompt(_ value: String?) {
    _systemPrompt = value
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
