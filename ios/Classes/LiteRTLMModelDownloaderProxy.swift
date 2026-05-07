//
//  LiteRTLMModelDownloaderProxy.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit



@objc(LiteRTLMModelDownloaderProxy)
public class LiteRTLMModelDownloaderProxy: TiProxy {

  private var _downloader: ModelDownloader?
  private var _modelsDirectory: String?

  @objc public var modelsDirectory: String? {
      get { return _modelsDirectory }
      set { _modelsDirectory = newValue; replaceValue(newValue, forKey: "modelsDirectory", notification: false) }
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public init(modelsDirectory: String?) {
    super._init(withPageContext: nil)
    if let dir = modelsDirectory {
      _modelsDirectory = dir
    }
  }

  // MARK: - Public API

  @objc
  public func download(_ modelInfo: LiteRTLMModelInfo) {
    Task {
      await modelInfo.downloader.download(model: modelInfo.toNative())
    }
  }

  @objc
  public func downloadFrom(_ url: String, fileName: String?, expectedSize: Int64?) {
    guard let url = URL(string: url) else {
      fireEvent("error", withObject: ["message": "Invalid URL"])
      return
    }
    Task {
      await downloader().download(from: url, fileName: fileName, expectedSize: expectedSize)
    }
  }

  @objc
  public func pause() {
    Task {
      await downloader().pause()
    }
  }

  @objc
  public func cancel() {
    Task {
      await downloader().cancel()
    }
  }

  @objc
  public func isDownloaded(_ modelInfo: LiteRTLMModelInfo) -> Bool {
    return downloader().isDownloaded(modelInfo.toNative())
  }

  @objc
  public func modelPath(_ modelInfo: LiteRTLMModelInfo) -> String? {
    return downloader().modelPath(for: modelInfo.toNative())?.path
  }

  @objc
  public func deleteModel(_ modelInfo: LiteRTLMModelInfo) {
    try? downloader().deleteModel(modelInfo.toNative())
  }

  @objc
  public func deleteModelByFileName(_ fileName: String) {
    try? downloader().deleteModel(fileName: fileName)
  }

  @objc
  public func getModelsDirectory() -> String? {
    return downloader().modelsDirectory.path
  }

  // MARK: - Internal

  private func downloader() -> ModelDownloader {
    if let dl = _downloader {
      return dl
    }
    let dir = _modelsDirectory != nil ? URL(fileURLWithPath: _modelsDirectory!) : nil
    let newDl = ModelDownloader(modelsDirectory: dir)
    _downloader = newDl
    return newDl
  }
}
