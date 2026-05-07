//
//  LiteRTLMContent.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMContent)
public class LiteRTLMContent: TiProxy {

  private var _type: String = "text"
  private var _text: String?
  private var _imageData: Data?
  private var _audioData: Data?
  private var _audioFormat: String = "wav"
  private var _maxDimension: Int = 1024

  @objc public var type: String {
      get { return _type }
      set { _type = newValue; replaceValue(newValue, forKey: "type", notification: false) }
  }

  @objc public var text: String? {
      get { return _text }
      set { _text = newValue; replaceValue(newValue, forKey: "text", notification: false) }
  }

  @objc public var imageData: Data? {
      get { return _imageData }
      set { _imageData = newValue; replaceValue(newValue, forKey: "imageData", notification: false) }
  }

  @objc public var audioData: Data? {
      get { return _audioData }
      set { _audioData = newValue; replaceValue(newValue, forKey: "audioData", notification: false) }
  }

  @objc public var audioFormat: String {
      get { return _audioFormat }
      set { _audioFormat = newValue; replaceValue(newValue, forKey: "audioFormat", notification: false) }
  }

  @objc public var maxDimension: Int {
      get { return _maxDimension }
      set { _maxDimension = newValue; replaceValue(newValue, forKey: "maxDimension", notification: false) }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  public static func text(_ value: String) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "text"
    content._text = value
    return content
  }

  public static func image(_ data: Data) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "image"
    content._imageData = data
    return content
  }

  public static func audio(_ data: Data, format: String) -> LiteRTLMContent {
    let content = LiteRTLMContent()
    content._type = "audio"
    content._audioData = data
    content._audioFormat = format
    return content
  }

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
