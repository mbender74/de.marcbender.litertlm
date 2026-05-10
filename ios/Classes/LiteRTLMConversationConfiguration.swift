//
//  LiteRTLMConversationConfiguration.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMConversationConfiguration)
public class LiteRTLMConversationConfiguration: TiProxy {

  internal var _maxOutputTokens: Int32 = 1024
  internal var _samplerType: String = "balanced"
  internal var _tools: [LiteRTLMTool] = []
  internal var _toolExecutionMode: String = "automatic"
  internal var _maxImageDimension: Int = 1024
  internal var _systemPrompt: String?

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

  public var sampler: LiteRTLMSamplerConfiguration?

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  public func toNative() -> ConversationConfiguration {
    NSLog("[DEBUG] toNative() START")
    var config = ConversationConfiguration()
    NSLog("[DEBUG] toNative() created default config")
    config = config.maxOutputTokens(_maxOutputTokens)
    NSLog("[DEBUG] toNative() set maxOutputTokens")
    config = config.maxImageDimension(_maxImageDimension)
    NSLog("[DEBUG] toNative() set maxImageDimension")

    if let sampler = sampler {
      NSLog("[DEBUG] toNative() using custom sampler")
      config = config.sampler(sampler.toNative())
    } else if _samplerType == "greedy" {
      NSLog("[DEBUG] toNative() using greedy sampler")
      config = config.sampler(.greedy)
    } else if _samplerType == "creative" {
      NSLog("[DEBUG] toNative() using creative sampler")
      config = config.sampler(.creative)
    } else {
      NSLog("[DEBUG] toNative() using balanced sampler")
      config = config.sampler(.balanced)
    }
    NSLog("[DEBUG] toNative() set sampler")

    if _toolExecutionMode == "manual" {
      NSLog("[DEBUG] toNative() set manual execution")
      config = config.toolExecution(.manual)
    } else {
      NSLog("[DEBUG] toNative() set automatic execution")
      config = config.toolExecution(.automatic)
    }
    NSLog("[DEBUG] toNative() set toolExecution")

    if let prompt = _systemPrompt {
      NSLog("[DEBUG] toNative() set systemPrompt: \(prompt.prefix(100))")
      config = config.systemPrompt(prompt)
    } else {
      NSLog("[DEBUG] toNative() no systemPrompt")
    }
    NSLog("[DEBUG] toNative() about to map tools, _tools.count = \(_tools.count)")

    let nativeTools = _tools.map { $0.toNative() }
    NSLog("[DEBUG] toNative() tools mapped, count = \(nativeTools.count)")
    if !nativeTools.isEmpty {
      config = config.tools(nativeTools)
    }
    NSLog("[DEBUG] toNative() RETURNING config")

    return config
  }
}
