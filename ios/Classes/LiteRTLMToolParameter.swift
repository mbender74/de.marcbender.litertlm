//
//  LiteRTLMToolParameter.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMToolParameter)
public class LiteRTLMToolParameter: TiProxy {

  private var _name: String = ""
  private var _type: String = "string"
  private var _description: String = ""
  private var _required: Bool = false

  @objc public var name: String {
    get { _name }
    set { _name = newValue }
  }

  @objc public var type: String {
    get { _type }
    set { _type = newValue }
  }

  @objc public var description: String {
    get { _description }
    set { _description = newValue }
  }

  @objc public var required: Bool {
    get { _required }
    set { _required = newValue }
  }

  @objc
  override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  @objc
  public func toNative() -> Tool.Parameter {
    let paramType: Tool.ParameterType
    switch _type {
    case "number": paramType = .number
    case "integer": paramType = .integer
    case "boolean": paramType = .boolean
    case "array": paramType = .array
    case "object": paramType = .object
    default: paramType = .string
    }
    return Tool.Parameter(name: _name, type: paramType, description: _description, required: _required)
  }
}
