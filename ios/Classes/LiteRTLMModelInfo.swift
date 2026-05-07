//
//  LiteRTLMModelInfo.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit



@objc(LiteRTLMModelInfo)
public class LiteRTLMModelInfo: TiProxy {

  private var _name: String = ""
  private var _displayName: String = ""
  private var _url: String = ""
  private var _expectedSize: Int64?
  private var _fileName: String = ""
  private var _nativeModel: ModelInfo?

  @objc public var name: String {
    get { _name }
    set { _name = newValue }
  }

  @objc public var displayName: String {
    get { _displayName }
    set { _displayName = newValue }
  }

  @objc public var url: String {
    get { _url }
    set { _url = newValue }
  }

  @objc public var expectedSize: Int64? {
    get { _expectedSize }
    set { _expectedSize = newValue }
  }

  @objc public var fileName: String {
    get { _fileName }
    set { _fileName = newValue }
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public static func gemma4E2B() -> LiteRTLMModelInfo {
    let info = LiteRTLMModelInfo()
    let native = ModelRegistry.gemma4E2B
    info._name = native.name
    info._displayName = native.displayName
    info._url = native.url.absoluteString
    info._expectedSize = native.expectedSize
    info._fileName = native.fileName
    info._nativeModel = native
    return info
  }

  @objc
  public static func gemma4E4B() -> LiteRTLMModelInfo {
    let info = LiteRTLMModelInfo()
    let native = ModelRegistry.gemma4E4B
    info._name = native.name
    info._displayName = native.displayName
    info._url = native.url.absoluteString
    info._expectedSize = native.expectedSize
    info._fileName = native.fileName
    info._nativeModel = native
    return info
  }

  @objc
  public func toNative() -> ModelInfo {
    if let native = _nativeModel {
      return native
    }
    return ModelInfo(
      name: _name,
      displayName: _displayName,
      url: URL(string: _url) ?? URL(string: "https://unknown")!,
      expectedSize: _expectedSize,
      fileName: _fileName.isEmpty ? nil : _fileName
    )
  }
}
