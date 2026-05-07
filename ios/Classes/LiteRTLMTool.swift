//
//  LiteRTLMTool.swift
//  TitaniumLiteRTLM
//
//  Created by Marc Bender
//  Copyright (c) 2026 by Your Company. All rights reserved.
//
import CLiteRTLM
import UIKit
import TitaniumKit


@objc(LiteRTLMTool)
public class LiteRTLMTool: TiProxy {

  internal var _name: String = ""
  internal var _description: String = ""
  internal var _parameters: [Any] = []
  internal var _executeCallback: KrollCallback?

  @objc public var name: String {
    get { _name }
    set { _name = newValue }
  }

  @objc public override var description: String {
    get { _description }
    set { _description = newValue }
  }

  @objc public var parameters: [Any] {
    get { _parameters }
    set { _parameters = newValue }
  }

  @objc public var executeCallback: KrollCallback? {
    get { _executeCallback }
    set { _executeCallback = newValue }
  }

  @objc
  public override func _init(withPageContext context: TiEvaluator!) -> Self? {
    super._init(withPageContext: context)
    return self
  }

  public func toNative() -> Tool {
    let params: [Tool.Parameter] = _parameters.compactMap { param -> Tool.Parameter? in
      if let dict = param as? [String: Any] {
        return Tool.Parameter(
          name: dict["name"] as? String ?? "",
          type: Tool.ParameterType(rawValue: dict["type"] as? String ?? "string") ?? .string,
          description: dict["description"] as? String ?? "",
          required: dict["required"] as? Bool ?? false
        )
      }
      return nil
    }

    return Tool(
      name: _name,
      description: _description,
      parameters: params,
      execute: { [weak self] args in
        guard let self = self else { return [:] }
        var result: [String: Any] = [:]

        if let callback = self._executeCallback {
          var resolvedResult: [String: Any]?
          let semaphore = DispatchSemaphore(value: 0)

          callback.call([args]) { (returned: Any?) in
            if let dict = returned as? [String: Any] {
              resolvedResult = dict
            } else if let str = returned as? String {
              resolvedResult = ["output": str]
            }
            semaphore.signal()
          }
          semaphore.wait()

          if let resolved = resolvedResult {
            result = resolved
          }
        }

        return result
      }
    )
  }
}
