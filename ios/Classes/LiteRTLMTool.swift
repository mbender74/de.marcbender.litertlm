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
      execute: { [weak self] args async throws -> [String: Any] in
        guard let self = self, let callback = self._executeCallback else { return [:] }

        let result: Any? = await withCheckedContinuation { continuation in
          var resumed = false

          DispatchQueue.main.async {
            let resultCallback = self.makeResultCallback { (returned: Any?) in
              if !resumed {
                resumed = true
                continuation.resume(returning: returned)
              }
            }

            var callArgs: [Any] = [args]
            if let rc = resultCallback {
              callArgs.append(rc)
            }
            let returned = callback.call(callArgs, thisObject: self)

            if !resumed {
              if let dict = returned as? [String: Any] {
                resumed = true
                continuation.resume(returning: dict)
              } else if let str = returned as? String {
                resumed = true
                continuation.resume(returning: ["output": str])
              } else {
                // JS didn't return a value synchronously and no resultCallback available
                resumed = true
                continuation.resume(returning: nil)
              }
            }
          }
        }

        if let dict = result as? [String: Any] {
          return dict
        } else if let str = result as? String {
          return ["output": str]
        }
        return [:]
      }
    )
  }

  /// Create a KrollCallback that wraps a Swift closure, so JS can call it.
  internal func makeResultCallback(_ handler: @escaping (Any?) -> Void) -> KrollCallback? {
    guard let execContext = self.executionContext,
          let krollContext = execContext.krollContext() else {
      NSLog("[LiteRTLMTool] ⚠️ No krollContext available for result callback")
      return nil
    }
    let jsContextRef = krollContext.context()
    let jsContext = JSContext(jsGlobalContextRef: jsContextRef)

    let blockValue = JSValue(object: { (arg: Any) -> Any? in
      handler(arg)
      return nil
    }, in: jsContext)

    guard let jsValueRef = blockValue?.jsValueRef else {
      NSLog("[LiteRTLMTool] ⚠️ Could not create JSValue for result callback")
      return nil
    }
    let globalObj = JSContextGetGlobalObject(jsContextRef)
    return KrollCallback(callback: jsValueRef, thisObject: globalObj, context: krollContext)
  }
}