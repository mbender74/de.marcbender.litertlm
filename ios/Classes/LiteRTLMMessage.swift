//
//  LiteRTLMMessage.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMMessage)
public class LiteRTLMMessage: TiProxy {

  private var _role: String = "user"
  private var _contents: [LiteRTLMContent] = []

  @objc public var role: String {
      get { return _role }
      set { _role = newValue; replaceValue(newValue, forKey: "role", notification: false) }
  }

  @objc public var contents: [LiteRTLMContent] {
      get { return _contents }
      set { _contents = newValue; replaceValue(newValue, forKey: "contents", notification: false) }
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
