//
//  LiteRTLMConversationProxy.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMConversationProxy)
public class LiteRTLMConversationProxy: TiProxy {

  private var _conversation: LMConversation?
  private var _isActive: Bool = false
  private var _engineProxy: LiteRTLMEngineProxy?
  private var _configuration: LiteRTLMConversationConfiguration?
  private var _history: [LiteRTLMMessage] = []

  @objc public var isActive: Bool {
      get { return _isActive }
      set { _isActive = newValue; replaceValue(newValue, forKey: "isActive", notification: false) }
  }

  @objc public var history: [LiteRTLMMessage] {
      get { return _history }
      set { _history = newValue; replaceValue(newValue, forKey: "history", notification: false) }
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  // MARK: - Public API

  @objc
  public func send(_ text: String) {
    let task = Task {
      do {
        guard let conversation = _conversation else { throw LiteRTLMError.noActiveConversation }
        _isActive = true
        let result = try await conversation.send(text)
        await MainActor.run {
          let msg = LiteRTLMMessage()
          msg._role = "model"
          msg._text = result
          _history.append(msg)
          fireEvent("message", withObject: ["role": "model", "content": result])
        }
        _isActive = false
      } catch {
        await MainActor.run {
          _isActive = false
          fireEvent("error", withObject: ["message": error.localizedDescription])
        }
      }
    }
    _ = task
  }

  @objc
  public func sendMultimodal(_ text: String, images: [[String: Any]], audio: [[String: Any]], audioFormat: String) {
    var imageData: [Data] = []
    for img in images {
      if let data = img["data"] as? Data {
        let maxDim = img["maxDimension"] as? Int ?? 1024
        do {
          let processed = try ImageUtilities.prepareForVision(data, maxDimension: maxDim)
          imageData.append(processed)
        } catch {
          // Skip invalid images
        }
      }
    }

    var audioData: [Data] = []
    for aud in audio {
      if let data = aud["data"] as? Data {
        var audioFormatVal: AudioFormat = .wav
        switch audioFormat {
        case "flac": audioFormatVal = .flac
        case "mp3": audioFormatVal = .mp3
        default: audioFormatVal = .wav
        }
        audioData.append(data)
      }
    }

    let task = Task {
      do {
        guard let conversation = _conversation else { throw LiteRTLMError.noActiveConversation }
        _isActive = true
        let result = try await conversation.send(text, images: imageData, audio: audioData, audioFormat: audioFormatVal)
        await MainActor.run {
          let msg = LiteRTLMMessage()
          msg._role = "model"
          msg._text = result
          _history.append(msg)
          fireEvent("message", withObject: ["role": "model", "content": result])
        }
        _isActive = false
      } catch {
        await MainActor.run {
          _isActive = false
          fireEvent("error", withObject: ["message": error.localizedDescription])
        }
      }
    }
    _ = task
  }

  @objc
  public func sendStream(_ text: String, images: [[String: Any]]?, audio: [[String: Any]]?, audioFormat: String) {
    var imageData: [Data] = []
    if let images = images {
      for img in images {
        if let data = img["data"] as? Data {
          let maxDim = img["maxDimension"] as? Int ?? 1024
          do {
            let processed = try ImageUtilities.prepareForVision(data, maxDimension: maxDim)
            imageData.append(processed)
          } catch {
            // Skip invalid images
          }
        }
      }
    }

    var audioData: [Data] = []
    if let audio = audio {
      for aud in audio {
        if let data = aud["data"] as? Data {
          var audioFormatVal: AudioFormat = .wav
          switch audioFormat {
          case "flac": audioFormatVal = .flac
          case "mp3": audioFormatVal = .mp3
          default: audioFormatVal = .wav
          }
          audioData.append(data)
        }
      }
    }

    guard let conversation = _conversation else {
      fireEvent("error", withObject: ["message": "No active conversation"])
      return
    }

    _isActive = true
    do {
      let stream = try conversation.sendStream(text, images: imageData, audio: audioData, audioFormat: audioFormatVal)
      Task {
        do {
          for try await token in stream {
            await MainActor.run {
              fireEvent("tokencode", withObject: ["token": token])
            }
          }
          await MainActor.run {
            _isActive = false
            let msg = LiteRTLMMessage()
            msg._role = "model"
            _history.append(msg)
            fireEvent("end", withObject: [:])
          }
        } catch {
          await MainActor.run {
            _isActive = false
            fireEvent("error", withObject: ["message": error.localizedDescription])
          }
        }
      }
    } catch {
      _isActive = false
      fireEvent("error", withObject: ["message": error.localizedDescription])
    }
  }

  @objc
  public func collectStream(_ text: String, images: [[String: Any]]?, audio: [[String: Any]]?, audioFormat: String) {
    var imageData: [Data] = []
    if let images = images {
      for img in images {
        if let data = img["data"] as? Data {
          let maxDim = img["maxDimension"] as? Int ?? 1024
          do {
            let processed = try ImageUtilities.prepareForVision(data, maxDimension: maxDim)
            imageData.append(processed)
          } catch {
            // skip
          }
        }
      }
    }

    var audioData: [Data] = []
    if let audio = audio {
      for aud in audio {
        if let data = aud["data"] as? Data {
          var audioFormatVal: AudioFormat = .wav
          switch audioFormat {
          case "flac": audioFormatVal = .flac
          case "mp3": audioFormatVal = .mp3
          default: audioFormatVal = .wav
          }
          audioData.append(data)
        }
      }
    }

    let task = Task {
      do {
        guard let conversation = _conversation else { throw LiteRTLMError.noActiveConversation }
        let stream = try conversation.sendStream(text, images: imageData, audio: audioData, audioFormat: audioFormatVal)
        let result = try await stream.collect()
        await MainActor.run {
          let msg = LiteRTLMMessage()
          msg._role = "model"
          msg._text = result
          _history.append(msg)
          fireEvent("message", withObject: ["role": "model", "content": result])
        }
      } catch {
        await MainActor.run {
          fireEvent("error", withObject: ["message": error.localizedDescription])
        }
      }
    }
    _ = task
  }

  @objc
  public func cancel() {
    _conversation?.cancel()
    _isActive = false
    fireEvent("cancelled", withObject: [:])
  }

  @objc
  public func close() {
    _conversation?.close()
    _isActive = false
    _history = []
    fireEvent("close", withObject: [:])
  }

  @objc
  public func getBenchmarkInfo() -> [String: Any]? {
    guard let conversation = _conversation else { return nil }
    guard let info = conversation.benchmarkInfo() else { return nil }
    return benchmarkInfoToDict(info)
  }

  // MARK: - Internal

  func addMessageToHistory(_ message: Message) {
    let msgProxy = LiteRTLMMessage()
    msgProxy._role = message.role.rawValue
    msgProxy._contents = message.content.map { content in
      let c = LiteRTLMContent()
      switch content {
      case .text(let t): c._text = t
      case .image(let d, let m): c._imageData = d; c._maxDimension = m
      case .audio(let d, let f): c._audioData = d; c._audioFormat = f.rawValue
      }
      return c
    }
    _history.append(msgProxy)
  }

  func benchmarkInfoToDict(_ info: BenchmarkInfo) -> [String: Any] {
    var dict: [String: Any] = [
      "initTime": info.initTime,
      "timeToFirstToken": info.timeToFirstToken,
      "averageDecodeSpeed": info.averageDecodeSpeed,
      "averagePrefillSpeed": info.averagePrefillSpeed,
      "totalTokensGenerated": info.totalTokensGenerated,
    ]
    let prefillTurns = info.prefillTurns.map { t -> [String: Any] in
      return ["tokensPerSecond": t.tokensPerSecond, "tokenCount": t.tokenCount]
    }
    let decodeTurns = info.decodeTurns.map { t -> [String: Any] in
      return ["tokensPerSecond": t.tokensPerSecond, "tokenCount": t.tokenCount]
    }
    dict["prefillTurns"] = prefillTurns
    dict["decodeTurns"] = decodeTurns
    return dict
  }
}
