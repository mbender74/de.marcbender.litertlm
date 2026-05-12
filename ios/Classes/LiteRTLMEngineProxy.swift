//
//  LiteRTLMEngineProxy.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMEngineProxy)
public class LiteRTLMEngineProxy: TiProxy {

  internal var _engine: LMEngine?
  internal var _status: String = "notLoaded"
  internal var _isReady: Bool = false
  internal var _lastError: String?
  internal var _configuration: EngineConfiguration?
  /// Strong refs to Tool proxies so their KrollCallbacks stay alive
  internal var _toolProxies: [AnyObject] = []

  @objc public var status: String {
      get { return _status }
      set { _status = newValue; replaceValue(newValue, forKey: "status", notification: false) }
  }

  @objc public var isReady: Bool {
      get { return _isReady }
      set { _isReady = newValue; replaceValue(newValue, forKey: "isReady", notification: false) }
  }

  @objc public var lastError: String? {
      get { return _lastError }
      set { _lastError = newValue; replaceValue(newValue, forKey: "lastError", notification: false) }
  }

  public var configuration: EngineConfiguration? {
      get { return _configuration }
      set { _configuration = newValue; replaceValue(newValue, forKey: "configuration", notification: false) }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  // MARK: - Public API

  @objc
  public func load() {
    DispatchQueue.main.async {
      do {
        guard let engine = self._engine else {
          self._status = "error"
          self._lastError = "Engine not initialized"
          self.fireEvent("error", with: ["message": "Engine not initialized"])
          return
        }
        self._status = "loading"
        self.isReady = false
        self.fireEvent("statuschange", with: ["status": "loading"])
        try engine.load()
        self._status = "ready"
        self.isReady = true
        self.fireEvent("statuschange", with: ["status": "ready"])
        self.fireEvent("ready", with: [:])
      } catch {
        self._status = "error"
        self._isReady = false
        self._lastError = error.localizedDescription
        self.fireEvent("error", with: ["message": error.localizedDescription, "error": error])
      }
    }
  }

  @objc
  public func unloadEngine() {
    DispatchQueue.main.async {
      guard let engine = self._engine else { return }
      engine.unload()
      self._status = "notLoaded"
      self._isReady = false
      self.fireEvent("statuschange", with: ["status": "notLoaded"])
    }
  }

  @objc
  public func createSession(_ configuration: LiteRTLMSessionConfiguration?) {
    DispatchQueue.main.async {
      do {
        guard let engine = self._engine, engine.isReady else {
          self._status = "error"
          self._lastError = "Engine is not ready or not initialized"
          self.fireEvent("error", with: ["message": "Engine is not ready or not initialized"])
          return
        }
        let sessionConfig: SessionConfiguration = configuration?.toNative() ?? SessionConfiguration()
        let session = try engine.createSession(configuration: sessionConfig)
        let proxy = LiteRTLMSessionProxy()
        proxy._session = session
        proxy._engineProxy = self
        proxy._configuration = configuration
        self.replaceValue(proxy, forKey: "session", notification: false)
        self.fireEvent("sessioncreated", with: ["session": proxy])
      } catch {
        self._status = "error"
        self._lastError = error.localizedDescription
        self.fireEvent("error", with: ["message": error.localizedDescription])
      }
    }
  }

  @objc
  public func createConversation(_ configuration: LiteRTLMConversationConfiguration?) {
    // Retain tool proxies so KrollCallbacks stay alive
    if let config = configuration {
      self._toolProxies = config._tools.map { $0 as AnyObject }
    }

    DispatchQueue.main.async {
      do {
        guard let engine = self._engine, engine.isReady else {
          self._status = "error"
          self._lastError = "Engine is not ready or not initialized"
          self.fireEvent("error", with: ["message": "Engine is not ready or not initialized"])
          return
        }
        let convConfig: ConversationConfiguration = configuration?.toNative() ?? ConversationConfiguration()
        let conversation = try engine.createConversation(configuration: convConfig)
        let proxy = LiteRTLMConversationProxy()
        proxy._conversation = conversation
        proxy._engineProxy = self
        proxy._configuration = configuration
        self.replaceValue(proxy, forKey: "conversation", notification: false)
        self.fireEvent("conversationcreated", with: ["conversation": proxy])
      } catch {
        self._status = "error"
        self._lastError = error.localizedDescription
        self.fireEvent("error", with: ["message": error.localizedDescription])
      }
    }
  }

  @objc
  public func createConversationWithConfig(_ configuration: Any) {
    NSLog("[DEBUG] createConversationWithConfig CALLED, type=\(type(of: configuration))")
    // Titanium wraps TiProxy in __NSArrayM - extract the proxy
    let config: LiteRTLMConversationConfiguration
    if let arr = configuration as? [Any], let c = arr.first as? LiteRTLMConversationConfiguration {
      config = c
    } else if let c = configuration as? LiteRTLMConversationConfiguration {
      config = c
    } else {
      // Fallback: use KVC on NSObject
      guard let obj = configuration as? NSObject else { return }
      let maxOutputTokens = obj.value(forKey: "maxOutputTokens") as? Int32 ?? 2048
      let samplerType = obj.value(forKey: "samplerType") as? String ?? "balanced"
      let toolExecutionMode = obj.value(forKey: "toolExecutionMode") as? String ?? "automatic"
      let maxImageDimension = obj.value(forKey: "maxImageDimension") as? Int ?? 1024
      let systemPrompt = obj.value(forKey: "systemPrompt") as? String
      let toolsArr = obj.value(forKey: "tools") as? [Any] ?? []

      var nativeTools: [Tool] = []
      for toolObj in toolsArr {
        guard let tObj = toolObj as? NSObject else { continue }
        let toolName = tObj.value(forKey: "name") as? String ?? ""
        let toolDesc = tObj.value(forKey: "description") as? String ?? ""
        var toolParams: [Tool.Parameter] = []
        if let paramsArr = tObj.value(forKey: "parameters") as? [Any] {
          for p in paramsArr {
            guard let pObj = p as? NSObject else { continue }
            toolParams.append(Tool.Parameter(
              name: pObj.value(forKey: "name") as? String ?? "",
              type: Tool.ParameterType(rawValue: pObj.value(forKey: "type") as? String ?? "string") ?? .string,
              description: pObj.value(forKey: "description") as? String ?? "",
              required: pObj.value(forKey: "required") as? Bool ?? false
            ))
          }
        }
        nativeTools.append(Tool(name: toolName, description: toolDesc, parameters: toolParams, execute: { _ in return [:] }))
      }

      // Build config and create conversation
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let engine = self._engine, engine.isReady else { return }
        do {
          var convConfig = ConversationConfiguration()
          convConfig = convConfig.maxOutputTokens(maxOutputTokens)
          convConfig = convConfig.maxImageDimension(maxImageDimension)
          if samplerType == "greedy" { convConfig = convConfig.sampler(.greedy) }
          else if samplerType == "creative" { convConfig = convConfig.sampler(.creative) }
          else { convConfig = convConfig.sampler(.balanced) }
          if toolExecutionMode == "manual" { convConfig = convConfig.toolExecution(.manual) }
          else { convConfig = convConfig.toolExecution(.automatic) }
          if let prompt = systemPrompt { convConfig = convConfig.systemPrompt(prompt) }
          if !nativeTools.isEmpty { convConfig = convConfig.tools(nativeTools) }

          let conversation = try engine.createConversation(configuration: convConfig)
          let proxy = LiteRTLMConversationProxy()
          proxy._conversation = conversation
          proxy._engineProxy = self
          self.replaceValue(proxy, forKey: "conversation", notification: false)
          // Fire on the module, not the engine proxy (JS listener is on litertlm module)
          if let module = DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule {
            module.fireEvent("conversationcreated", with: ["conversation": proxy])
          }
        } catch {
          self._status = "error"
          self._lastError = error.localizedDescription
          if let module = DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule {
            module.fireEvent("error", with: ["message": error.localizedDescription])
          }
        }
      }
      return
    }

    // CRITICAL: Copy all values IMMEDIATELY before any async dispatch.
    // Titanium retains the proxy for the method call, but once we dispatch
    // to DispatchQueue.main.async, the JS GC can free the underlying JS object.
    // We must extract all scalar values now while the proxy is still valid.
    let maxOutputTokens = config.maxOutputTokens
    let samplerType = config.samplerType
    let toolExecutionMode = config.toolExecutionMode
    let maxImageDimension = config.maxImageDimension
    let systemPrompt = config.systemPrompt

    // Copy tools immediately (each tool is a TiProxy, extract scalars)
    // Preserve strong refs to proxies so the KrollCallback stays alive
    var toolProxies: [AnyObject] = []
    var nativeTools: [Tool] = []
    for tool in config.tools {
      guard let t = tool as? LiteRTLMTool else { continue }
      let toolName = t.name
      let toolDesc = t.description
      var toolParams: [Tool.Parameter] = []
      for param in t.parameters {
        if let dict = param as? [String: Any] {
          toolParams.append(Tool.Parameter(
            name: dict["name"] as? String ?? "",
            type: Tool.ParameterType(rawValue: dict["type"] as? String ?? "string") ?? .string,
            description: dict["description"] as? String ?? "",
            required: dict["required"] as? Bool ?? false
          ))
        }
      }
      // Keep strong ref to the proxy so KrollCallback doesn't die
      toolProxies.append(t)

      nativeTools.append(Tool(
        name: toolName,
        description: toolDesc,
        parameters: toolParams,
        execute: { [weak t] args async throws -> [String: Any] in
          guard let proxy = t, let callback = proxy._executeCallback else { return [:] }

          let result: Any? = await withCheckedContinuation { continuation in
            var resumed = false

            DispatchQueue.main.async {
              let resultCallback = proxy.makeResultCallback { (returned: Any?) in
                if !resumed {
                  resumed = true
                  continuation.resume(returning: returned)
                }
              }

              var callArgs: [Any] = [args]
              if let rc = resultCallback {
                callArgs.append(rc)
              }
              let returned = callback.call(callArgs, thisObject: proxy)

              if !resumed {
                if let dict = returned as? [String: Any] {
                  resumed = true
                  continuation.resume(returning: dict)
                } else if let str = returned as? String {
                  resumed = true
                  continuation.resume(returning: ["output": str])
                } else {
                  resumed = true
                  continuation.resume(returning: nil)
                }
              }
            }
          }

          if let dict = result as? [String: Any] {
            return dict
          } else if let str = result as? String {
            return ["output": str]
          }
          return [:]
        }
      ))
    }

    // Store tool proxies on self so they survive beyond this method
    self._toolProxies = toolProxies

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      do {
        guard let engine = self._engine else {
          self._status = "error"
          self._lastError = "Engine is not ready or not initialized"
          self.fireEvent("error", with: ["message": "Engine is not ready or not initialized"])
          return
        }
        guard engine.isReady else {
          self._status = "error"
          self._lastError = "Engine is not ready or not initialized"
          self.fireEvent("error", with: ["message": "Engine is not ready or not initialized"])
          return
        }

        // Build the native config from the copied values (no JS pointer deref)
        var convConfig = ConversationConfiguration()
        convConfig = convConfig.maxOutputTokens(maxOutputTokens)
        convConfig = convConfig.maxImageDimension(maxImageDimension)

        if samplerType == "greedy" {
          convConfig = convConfig.sampler(.greedy)
        } else if samplerType == "creative" {
          convConfig = convConfig.sampler(.creative)
        } else {
          convConfig = convConfig.sampler(.balanced)
        }

        if toolExecutionMode == "manual" {
          convConfig = convConfig.toolExecution(.manual)
        } else {
          convConfig = convConfig.toolExecution(.automatic)
        }

        if let prompt = systemPrompt {
          convConfig = convConfig.systemPrompt(prompt)
        }

        if !nativeTools.isEmpty {
          convConfig = convConfig.tools(nativeTools)
        }

        let conversation = try engine.createConversation(configuration: convConfig)

        let proxy = LiteRTLMConversationProxy()
        proxy._conversation = conversation
        proxy._engineProxy = self
        proxy._configuration = config
        self.replaceValue(proxy, forKey: "conversation", notification: false)
        // Fire on the module, not the engine proxy (JS listener is on litertlm module)
        if let module = DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule {
          module.fireEvent("conversationcreated", with: ["conversation": proxy])
        }
      } catch {
        self._status = "error"
        self._lastError = error.localizedDescription
        // Fire on the module, not the engine proxy (JS listener is on litertlm module)
        if let module = DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule {
          module.fireEvent("error", with: ["message": error.localizedDescription])
        }
      }
    }
  }

  // MARK: - Internal

  func setEngine(_ engine: LMEngine) {
    _engine = engine
    _configuration = engine.configuration
  }
}
