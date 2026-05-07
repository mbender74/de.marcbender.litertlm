//
//  LiteRTLMContent.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMContent)
public class LiteRTLMContent: TiProxy {

  private var _type: String = "text"
  private var _text: String?
  private var _imageData: Data?
  private var _audioData: Data?
  private var _audioFormat: String = "wav"
  private var _maxDimension: Int = 1024

  @objc public private(set) var type: String = "text"

  @objc public func getType() -> String {
    return _type
  }

  @objc public func setType(_ value: String) {
    _type = value
  }

  @objc public private(set) var text: String?

  @objc public func getText() -> String? {
    return _text
  }

  @objc public func setText(_ value: String?) {
    _text = value
  }

  @objc public private(set) var imageData: Data?

  @objc public func getImageData() -> Data? {
    return _imageData
  }

  @objc public func setImageData(_ value: Data?) {
    _imageData = value
  }

  @objc public private(set) var audioData: Data?

  @objc public func getAudioData() -> Data? {
    return _audioData
  }

  @objc public func setAudioData(_ value: Data?) {
    _audioData = value
  }

  @objc public private(set) var audioFormat: String = "wav"

  @objc public func getAudioFormat() -> String {
    return _audioFormat
  }

  @objc public func setAudioFormat(_ value: String) {
    _audioFormat = value
  }

  @objc public private(set) var maxDimension: Int = 1024

  @objc public func getMaxDimension() -> Int {
    return _maxDimension
  }

  @objc public func setMaxDimension(_ value: Int) {
    _maxDimension = value
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public static func text(_ value: String) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "text"
    content._text = value
    return content
  }

  @objc
  public static func image(_ data: Data) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "image"
    content._imageData = data
    return content
  }

  @objc
  public static func audio(_ data: Data, format: String) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "audio"
    content._audioData = data
    content._audioFormat = format
    return content
  }

  @objc
  public func toNative() -> Content {
    switch _type {
    case "image":
      return .image(_imageData ?? Data(), maxDimension: _maxDimension)
    case "audio":
      var audioFormat: AudioFormat = .wav
      switch _audioFormat {
      case "flac": audioFormat = .flac
      case "mp3": audioFormat = .mp3
      default: audioFormat = .wav
      }
      return .audio(_audioData ?? Data(), format: audioFormat)
    default:
      return .text(_text ?? "")
    }
  }
}
