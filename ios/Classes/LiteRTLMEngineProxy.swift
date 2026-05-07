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

  private var _engine: LMEngine?
  private var _status: String = "notLoaded"
  private var _isReady: Bool = false
  private var _lastError: String?
  private var _configuration: EngineConfiguration?

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
    Task {
      do {
        guard let engine = _engine else {
          await MainActor.run {
            _status = "error"
            _lastError = "Engine not initialized"
            fireEvent("error", withObject: ["message": "Engine not initialized"])
          }
          return
        }
        _status = "loading"
        isReady = false
        fireEvent("statuschange", withObject: ["status": "loading"])
        try await engine.load()
        await MainActor.run {
          _status = "ready"
          _isReady = true
          fireEvent("statuschange", withObject: ["status": "ready"])
          fireEvent("ready", withObject: [:])
        }
      } catch {
        await MainActor.run {
          _status = "error"
          _isReady = false
          _lastError = error.localizedDescription
          fireEvent("error", withObject: ["message": error.localizedDescription, "error": error])
        }
      }
    }
  }

  @objc
  public func unload() {
    Task {
      guard let engine = _engine else { return }
      engine.unload()
      await MainActor.run {
        _status = "notLoaded"
        _isReady = false
        fireEvent("statuschange", withObject: ["status": "notLoaded"])
      }
    }
  }

  @objc
  public func createSession(_ configuration: LiteRTLMSessionConfiguration?) {
    Task {
      do {
        guard let engine = _engine, engine.isReady else {
          await MainActor.run {
            _status = "error"
            _lastError = "Engine is not ready or not initialized"
            fireEvent("error", withObject: ["message": "Engine is not ready or not initialized"])
          }
          return
        }
        let sessionConfig: SessionConfiguration = configuration?.toNative() ?? SessionConfiguration()
        let session = try await engine.createSession(configuration: sessionConfig)
        let proxy = LiteRTLMSessionProxy()
        proxy._session = session
        proxy._engineProxy = self
        proxy._configuration = configuration
        replaceValue(proxy, forKey: "session", notification: false)
        fireEvent("sessioncreated", withObject: ["session": proxy])
      } catch {
        await MainActor.run {
          _status = "error"
          _lastError = error.localizedDescription
          fireEvent("error", withObject: ["message": error.localizedDescription])
        }
      }
    }
  }

  @objc
  public func createConversation(_ configuration: LiteRTLMConversationConfiguration?) {
    Task {
      do {
        guard let engine = _engine, engine.isReady else {
          await MainActor.run {
            _status = "error"
            _lastError = "Engine is not ready or not initialized"
            fireEvent("error", withObject: ["message": "Engine is not ready or not initialized"])
          }
          return
        }
        let convConfig: ConversationConfiguration = configuration?.toNative() ?? ConversationConfiguration()
        let conversation = try await engine.createConversation(configuration: convConfig)
        let proxy = LiteRTLMConversationProxy()
        proxy._conversation = conversation
        proxy._engineProxy = self
        proxy._configuration = configuration
        replaceValue(proxy, forKey: "conversation", notification: false)
        fireEvent("conversationcreated", withObject: ["conversation": proxy])
      } catch {
        await MainActor.run {
          _status = "error"
          _lastError = error.localizedDescription
          fireEvent("error", withObject: ["message": error.localizedDescription])
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
