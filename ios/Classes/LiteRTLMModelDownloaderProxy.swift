//
//  LiteRTLMModelDownloaderProxy.swift
//  TitaniumLiteRTLM
//
//  No CLiteRTLM import here – delegates to module to avoid Swift metadata crash
//

import UIKit
import TitaniumKit

@objc(LiteRTLMModelDownloaderProxy)
public class LiteRTLMModelDownloaderProxy: TiProxy {

  @objc public var modelsDirectory: String? {
    get { return _modelsDirectory as? String }
    set {
      _modelsDirectory = newValue as NSString?
      replaceValue(newValue, forKey: "modelsDirectory", notification: false)
    }
  }

  private var _modelsDirectory: NSString?

  override init() {
    super.init()
  }

  override public func _init(withProperties properties: [AnyHashable : Any]!) {
    super._init(withProperties: properties)
    if let dir = properties["modelsDirectory"] as? String {
      _modelsDirectory = dir as NSString
    }
  }

  // MARK: - Public API (delegates to module for CLiteRTLM work)

  @objc
  public func download(_ modelInfo: Any?) {
    guard let module = module() else { return }
    module.delegateDownload(with: modelInfo, proxy: self)
  }

  @objc
  public func downloadFrom(_ url: String, fileName: String?, expectedSize: NSNumber?) {
    guard let module = module() else { return }
    module.delegateDownloadFrom(url: url, fileName: fileName, expectedSize: expectedSize, proxy: self)
  }

  @objc
  public func pause() {
    guard let module = module() else { return }
    module.delegatePauseDownload(proxy: self)
  }

  @objc
  public func cancel() {
    guard let module = module() else { return }
    module.delegateCancelDownload(proxy: self)
  }

  @objc
  public func isDownloaded(_ modelInfo: Any?) -> Bool {
    guard let module = module() else { return false }
    return module.delegateIsDownloaded(with: modelInfo, proxy: self)
  }

  @objc
  public func modelPath(_ modelInfo: Any?) -> String? {
    guard let module = module() else { return nil }
    return module.delegateModelPath(for: modelInfo, proxy: self)
  }

  @objc
  public func deleteModel(_ modelInfo: Any?) {
    guard let module = module() else { return }
    module.delegateDeleteModel(with: modelInfo, proxy: self)
  }

  @objc
  public func deleteModelByFileName(_ fileName: String) {
    guard let module = module() else { return }
    module.delegateDeleteModel(fileName: fileName, proxy: self)
  }

  @objc
  public func getModelsDirectory() -> String? {
    return _modelsDirectory as String?
  }

  // MARK: - Helper

  private func module() -> DeMarcbenderLitertlmModule? {
    return DeMarcbenderLitertlmModule._moduleRef as? DeMarcbenderLitertlmModule
  }
}
