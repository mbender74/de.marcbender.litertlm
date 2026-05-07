//
//  LiteRTLMMessage.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM


@objc(LiteRTLMMessage)
public class LiteRTLMMessage: TiProxy {

  private var _role: String = "user"
  private var _contents: [LiteRTLMContent] = []

  @objc public private(set) var role: String = "user"

  @objc public func getRole() -> String {
    return _role
  }

  @objc public func setRole(_ value: String) {
    _role = value
  }

  @objc public private(set) var contents: [LiteRTLMContent] = []

  @objc public func getContents() -> [LiteRTLMContent] {
    return _contents
  }

  @objc public func setContents(_ value: [LiteRTLMContent]) {
    _contents = value
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public static func user(_ text: String) -> LiteRTLMMessage {
    let msg = LiteRTLMMessage()
    msg._role = "user"
    msg._contents = [LiteRTLMContent.text(text)]
    return msg
  }

  @objc
  public static func model(_ text: String) -> LiteRTLMMessage {
    let msg = LiteRTLMMessage()
    msg._role = "model"
    msg._contents = [LiteRTLMContent.text(text)]
    return msg
  }

  @objc
  public static func system(_ text: String) -> LiteRTLMMessage {
    let msg = LiteRTLMMessage()
    msg._role = "system"
    msg._contents = [LiteRTLMContent.text(text)]
    return msg
  }

  @objc
  public func toNative() -> Message {
    let contents = _contents.map { $0.toNative() }
    return Message(role: Role(rawValue: _role) ?? .user, content: contents)
  }
}
