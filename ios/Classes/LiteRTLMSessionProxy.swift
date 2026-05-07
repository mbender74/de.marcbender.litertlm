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
    let task = Task<String?, Error> {
      do {
        guard let session = _session else { throw LiteRTLMError.noActiveSession }
        let template: PromptTemplate = templateToNative(template) ?? .gemma
        let result = try await session.generate(prompt, template: template)
        await MainActor.run {
          fireEvent("generatelogic", with: ["result": result])
        }
        return nil
      } catch {
        await MainActor.run {
          fireEvent("error", with: ["message": error.localizedDescription])
        }
        return nil
      }
    }
    let taskId = String(_taskCounter); _taskCounter += 1
    _activeTasks[taskId] = task
    _ = _activeTasks.removeValue(forKey: taskId)
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

    let task = Task<String?, Error> {
      do {
        guard let session = _session else { throw LiteRTLMError.noActiveSession }
        let template: PromptTemplate = templateToNative(template) ?? .gemma
        let result = try await session.generate(text: text, images: imageData, audio: audioData, template: template)
        await MainActor.run {
          fireEvent("generatelogic", with: ["result": result])
        }
        return nil
      } catch {
        await MainActor.run {
          fireEvent("error", with: ["message": error.localizedDescription])
        }
        return nil
      }
    }
    let taskId = String(_taskCounter); _taskCounter += 1
    _activeTasks[taskId] = task
    _ = _activeTasks.removeValue(forKey: taskId)
  }

  @objc
  public func generateStream(_ prompt: String, template: String?) {
    guard let session = _session else {
      fireEvent("error", with: ["message": "No active session"])
      return
    }
    let template: PromptTemplate = templateToNative(template) ?? .gemma
    let stream = session.generateStream(prompt, template: template)

    Task {
      _isActive = true
      do {
        for try await token in stream {
          await MainActor.run {
            fireEvent("tokencode", with: ["token": token])
          }
        }
        await MainActor.run {
          _isActive = false
          fireEvent("end", with: [:])
        }
      } catch {
        await MainActor.run {
          _isActive = false
          fireEvent("error", with: ["message": error.localizedDescription])
        }
      }
    }
  }

  @objc
  public func collectStream(_ prompt: String, template: String?) {
    let task: Task<String?, Error> = Task {
      do {
        guard let session = _session else { throw LiteRTLMError.noActiveSession }
        let template: PromptTemplate = templateToNative(template) ?? .gemma
        let stream = session.generateStream(prompt, template: template)
        let result = try await stream.collect()
        await MainActor.run {
          fireEvent("generatelogic", with: ["result": result])
        }
        return result
      } catch {
        await MainActor.run {
          fireEvent("error", with: ["message": error.localizedDescription])
        }
        return ""
      }
    }
    let taskId = String(_taskCounter); _taskCounter += 1
    _activeTasks[taskId] = task
    _ = _activeTasks.removeValue(forKey: taskId)
  }

  @objc
  public func close() {
    _session?.close()
    _isActive = false
    fireEvent("close", with: [:])
  }

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
