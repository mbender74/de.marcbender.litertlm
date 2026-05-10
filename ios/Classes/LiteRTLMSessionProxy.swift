//
//  LiteRTLMSessionProxy.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMSessionProxy)
public class LiteRTLMSessionProxy: TiProxy {

  internal var _session: LMSession?
  internal var _isActive: Bool = false
  internal var _engineProxy: LiteRTLMEngineProxy?
  internal var _configuration: LiteRTLMSessionConfiguration?
  internal var _activeTasks: [String: Task<Optional<String>, Error>] = [:]
  internal var _taskCounter: Int = 0

  @objc public var isActive: Bool {
      get { return _isActive }
      set { _isActive = newValue; replaceValue(newValue, forKey: "isActive", notification: false) }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  // MARK: - Public API

  @objc
  public func generate(_ prompt: String, template: String?) {
    DispatchQueue.main.async {
      do {
        guard let session = self._session else {
          self.fireEvent("error", with: ["message": "No active session"])
          return
        }
        let template: PromptTemplate = templateToNative(template) ?? .gemma
        let result = try session.generate(prompt, template: template)
        self.fireEvent("generatelogic", with: ["result": result])
      } catch {
        self.fireEvent("error", with: ["message": error.localizedDescription])
      }
    }
  }

  @objc
  public func generateMultimodal(_ text: String, images: [[String: Any]], audio: [[String: Any]], template: String?) {
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
        let format = aud["format"] as? String ?? "wav"
        var audioFormat: AudioFormat = .wav
        switch format {
        case "flac": audioFormat = .flac
        case "mp3": audioFormat = .mp3
        default: audioFormat = .wav
        }
        audioData.append(data)
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      do {
        guard let session = self._session else {
          self.fireEvent("error", with: ["message": "No active session"])
          return
        }
        let template: PromptTemplate = templateToNative(template) ?? .gemma
        let result = try session.generate(text: text, images: imageData, audio: audioData, template: template)
        self.fireEvent("generatelogic", with: ["result": result])
      } catch {
        self.fireEvent("error", with: ["message": error.localizedDescription])
      }
    }
  }

  @objc
  public func generateStream(_ prompt: String, template: String?) {
   DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let session = self._session else {
        self.fireEvent("error", with: ["message": "No active session"])
        return
      }
      let template: PromptTemplate = templateToNative(template) ?? .gemma
      let stream = session.generateStream(prompt, template: template)

      self._isActive = true
      self.fireEvent("streamstart", with: [:])

      Task {
        do {
          for try await token in stream {
            await MainActor.run {
              self.fireEvent("tokencode", with: ["token": token])
            }
          }
          await MainActor.run {
            self._isActive = false
            self.fireEvent("end", with: [:])
          }
        } catch {
          await MainActor.run {
            self._isActive = false
            self.fireEvent("error", with: ["message": error.localizedDescription])
          }
        }
      }
    }
  }

  @objc
  public func close() {
    DispatchQueue.main.async { [weak self] in
      self?._session?.close()
      self?._isActive = false
      self?.fireEvent("close", with: [:])
    }
  }

  @objc
  public func getBenchmarkInfo() -> [String: Any]? {
    guard let session = _session else { return nil }
    guard let info = session.benchmarkInfo() else { return nil }
    return benchmarkInfoToDict(info)
  }

  // MARK: - Internal

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

private func templateToNative(_ template: String?) -> PromptTemplate? {
  guard let template = template else { return nil }
  switch template {
  case "gemma": return .gemma
  case "gemmaLegacy": return .gemmaLegacy
  case "raw": return .raw
  default: return nil
  }
}
