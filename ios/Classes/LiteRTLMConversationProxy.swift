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

  internal var _conversation: LMConversation?
  internal var _isActive: Bool = false
  internal var _engineProxy: LiteRTLMEngineProxy?
  internal var _configuration: LiteRTLMConversationConfiguration?
  internal var _history: [LiteRTLMMessage] = []

  @objc public var isActive: Bool {
      get { return _isActive }
      set { _isActive = newValue; replaceValue(newValue, forKey: "isActive", notification: false) }
  }

  @objc public var history: [LiteRTLMMessage] {
      get { return _history }
      set { _history = newValue; replaceValue(newValue, forKey: "history", notification: false) }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  // MARK: - Public API

  @objc
  public func send(_ text: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      Task {
        do {
          guard let conversation = self._conversation else {
            self.fireEvent("error", with: ["message": "No active conversation"])
            return
          }
          self._isActive = true
          let result = try await conversation.send(text)
          self._isActive = false
          let msg = LiteRTLMMessage()
          msg._role = "model"
          let content = LiteRTLMContent()
          content._text = result
          msg._contents = [content]
          self._history.append(msg)
          self.fireEvent("message", with: ["role": "model", "content": result])
        } catch {
          self._isActive = false
          self.fireEvent("error", with: ["message": error.localizedDescription])
        }
      }
    }
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
    var audioFormatVal: AudioFormat = .wav
    switch audioFormat {
    case "flac": audioFormatVal = .flac
    case "mp3": audioFormatVal = .mp3
    default: audioFormatVal = .wav
    }

    for aud in audio {
      if let data = aud["data"] as? Data {
        audioData.append(data)
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      Task {
        do {
          guard let conversation = self._conversation else {
            self.fireEvent("error", with: ["message": "No active conversation"])
            return
          }
          self._isActive = true
          let result = try await conversation.send(text, images: imageData, audio: audioData, audioFormat: audioFormatVal)
          self._isActive = false
          let msg = LiteRTLMMessage()
          msg._role = "model"
          let content = LiteRTLMContent()
          content._text = result
          msg._contents = [content]
          self._history.append(msg)
          self.fireEvent("message", with: ["role": "model", "content": result])
        } catch {
          self._isActive = false
          self.fireEvent("error", with: ["message": error.localizedDescription])
        }
      }
    }
  }

  @objc
  public func sendStream(_ message: Any?) {
    NSLog("[DEBUG] sendStream CALLED, type=\(type(of: message))")

    // Titanium wraps TiProxy in NSArray - extract first element
    let unwrapped: Any
    if let arr = message as? [Any], let first = arr.first {
      unwrapped = first
    } else {
      unwrapped = message ?? ()
    }
    NSLog("[DEBUG] sendStream: unwrapped type=\(type(of: unwrapped))")

    // Extract text from LiteRTLMMessage proxy
    let text: String
    if let msg = unwrapped as? LiteRTLMMessage {
      // Extract text from contents array
      text = msg._contents.compactMap { c -> String? in
        if let c = c as? LiteRTLMContent, c._type == "text" {
          return c._text
        }
        return nil
      }.joined(separator: " ")
      NSLog("[DEBUG] sendStream: extracted text, contentsCount=\(msg._contents.count), text='\(text)'")
    } else if let t = unwrapped as? String {
      text = t
      NSLog("[DEBUG] sendStream: extracted text from String")
    } else {
      NSLog("[DEBUG] sendStream: invalid message type \(type(of: unwrapped))")
      self.fireEvent("error", with: ["message": "Invalid message type"])
      return
    }

    var imageData: [Data] = []
    if let msg = unwrapped as? LiteRTLMMessage {
      for content in msg._contents {
        if let c = content as? LiteRTLMContent, c._type == "image" {
          if let data = c._imageData {
            let maxDim = c._maxDimension ?? 1024
            do {
              let processed = try ImageUtilities.prepareForVision(data, maxDimension: maxDim)
              imageData.append(processed)
            } catch {}
          }
        }
      }
    }

    var audioData: [Data] = []
    var audioFormatVal: AudioFormat = .wav
    if let msg = unwrapped as? LiteRTLMMessage {
      for content in msg._contents {
        if let c = content as? LiteRTLMContent, c._type == "audio" {
          if let data = c._audioData {
            audioFormatVal = AudioFormat(rawValue: c._audioFormat ?? "wav") ?? .wav
            audioData.append(data)
          }
        }
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        NSLog("[DEBUG] sendStream: self is nil")
        return
      }
      guard let conversation = self._conversation else {
        NSLog("[DEBUG] sendStream: _conversation is nil")
        self.fireEvent("error", with: ["message": "No active conversation"])
        return
      }
      NSLog("[DEBUG] sendStream: _conversation exists, starting stream")

      self._isActive = true
      self.fireEvent("streamstart", with: [:])
      NSLog("[DEBUG] sendStream: FIRED streamstart")

      Task {
        do {
          let stream = try conversation.sendStream(text, images: imageData, audio: audioData, audioFormat: audioFormatVal)
          for try await token in stream {
            await MainActor.run {
              NSLog("[DEBUG] sendStream: FIRED token, text='\(token)'")
              self.fireEvent("token", with: ["token": token])
            }
          }
          await MainActor.run {
            self._isActive = false
            let msg = LiteRTLMMessage()
            msg._role = "model"
            self._history.append(msg)
            self.fireEvent("streamcomplete", with: [:])
            NSLog("[DEBUG] sendStream: FIRED streamcomplete")
            self.fireEvent("streamend", with: [:])
            NSLog("[DEBUG] sendStream: FIRED streamend")
          }
        } catch {
          NSLog("[DEBUG] sendStream: ERROR \(error.localizedDescription)")
          await MainActor.run {
            self._isActive = false
            self.fireEvent("streamerror", with: ["message": error.localizedDescription])
            NSLog("[DEBUG] sendStream: FIRED streamerror")
          }
        }
      }
    }
  }

  @objc
  public func cancelStream() {
    DispatchQueue.main.async { [weak self] in
      self?._conversation?.cancel()
      self?._isActive = false
      self?.fireEvent("cancelled", with: [:])
    }
  }

  @objc
  public func closeConversation() {
    DispatchQueue.main.async { [weak self] in
      self?._conversation?.close()
      self?._isActive = false
      self?._history = []
      self?.fireEvent("close", with: [:])
    }
  }

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
