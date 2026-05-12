import CLiteRTLM
import UIKit
import TitaniumKit
import os.log
private let logger = Logger(subsystem: "com.litertlm", category: "conversation")

// MARK: - File-private Tool Call Helpers
// Defined outside LMConversation to avoid Self capture in C function pointer closures.

private struct ToolCallInfo {
    let name: String
    let arguments: [String: Any]
}

private func tryParseToolCallForStream(_ str: String) -> ToolCallInfo? {
    guard let data = str.data(using: .utf8) else {
        return parseGemma4ToolCall(str)
    }

    // If valid JSON, parse and try Gemma 4 on extracted text only.
    // Do NOT call parseGemma4ToolCall on raw JSON — backslash-escaped quotes break args.
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let tc = extractToolCallFromJSON(json) {
            return tc
        }

        for key in ["text", "content"] {
            if let inner = json[key] as? String {
                if let tc = parseGemma4ToolCall(inner) {
                    return tc
                }
                let innerCleaned = stripControlTokensForStream(inner)
                if let innerData = innerCleaned.data(using: .utf8),
                   let innerJson = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
                    if let tc = extractToolCallFromJSON(innerJson) {
                        return tc
                    }
                }
            }
        }

        if let content = json["content"] as? [[String: Any]] {
            for part in content {
                if let inner = part["text"] as? String {
                    if let tc = parseGemma4ToolCall(inner) {
                        return tc
                    }
                    let innerCleaned = stripControlTokensForStream(inner)
                    if let innerData = innerCleaned.data(using: .utf8),
                       let innerJson = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any],
                       let tc = extractToolCallFromJSON(innerJson) {
                        return tc
                    }
                }
            }
        }

        return nil
    }

    // Not JSON — try Gemma 4 on raw string (e.g., streaming already extracted text)
    return parseGemma4ToolCall(str)
}

private func extractToolCallFromJSON(_ json: [String: Any]) -> ToolCallInfo? {
    if let funcCall = json["function_call"] as? [String: Any],
       let name = funcCall["name"] as? String {
        return ToolCallInfo(name: name, arguments: extractArgumentsFromJSON(funcCall["arguments"]))
    }

    if let toolCalls = json["tool_calls"] as? [[String: Any]],
       let first = toolCalls.first,
       let function = first["function"] as? [String: Any],
       let name = function["name"] as? String {
        return ToolCallInfo(name: name, arguments: extractArgumentsFromJSON(function["arguments"]))
    }

    return nil
}

private func extractArgumentsFromJSON(_ arg: Any?) -> [String: Any] {
    if let dict = arg as? [String: Any] { return dict }
    if let str = arg as? String,
       let data = str.data(using: .utf8),
       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        return dict
    }
    return [:]
}

/// Parse Gemma 4 native tool call format: `<|tool_call>call:NAME{ARGS}<tool_call|>`
private func parseGemma4ToolCall(_ text: String) -> ToolCallInfo? {
    guard let callRange = text.range(of: "call:", options: []) else { return nil }

    // Verify there's a tool_call marker before "call:"
    let prefix = text[text.startIndex..<callRange.lowerBound]
    guard prefix.contains("tool_call") else { return nil }

    // Extract function name (between "call:" and first "{")
    let afterCall = text[callRange.upperBound...]
    guard let braceStart = afterCall.firstIndex(of: "{") else { return nil }
    let name = String(afterCall[afterCall.startIndex..<braceStart])
        .trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return nil }

    // Find matching closing brace (handles nested braces)
    var depth = 0
    var braceEnd: String.Index? = nil
    for i in afterCall.indices {
        if afterCall[i] == "{" { depth += 1 }
        else if afterCall[i] == "}" {
            depth -= 1
            if depth == 0 { braceEnd = i; break }
        }
    }
    guard let end = braceEnd else { return nil }

    let argsStr = String(afterCall[afterCall.index(after: braceStart)..<end])
    let args: [String: Any]
    if !argsStr.isEmpty {
        let fixed = fixUnquotedKeys(argsStr)
        let jsonStr = "{\(fixed)}"
        if let data = jsonStr.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            args = dict
        } else {
            NSLog("[LMConversation] ⚠️ Gemma4 args parse failed: '\(argsStr)' → jsonStr: '\(jsonStr)'")
            args = [:]
        }
    } else {
        args = [:]
    }

    NSLog("[LMConversation] ✅ Gemma4 tool call parsed: \(name) args=\(args)")
    return ToolCallInfo(name: name, arguments: args)
}

/// Fix unquoted JSON keys: `{city: "Berlin"}` → `{"city": "Berlin"}`
/// Also handles bare keys at string start: `city: "Berlin"` → `"city": "Berlin"`
private func fixUnquotedKeys(_ str: String) -> String {
    let pattern = "([\\{,\\s]|^)([a-zA-Z_][a-zA-Z0-9_]*)\\s*:"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return str }
    let nsRange = NSRange(str.startIndex..., in: str)
    return regex.stringByReplacingMatches(
        in: str, options: [], range: nsRange,
        withTemplate: "$1\"$2\":"
    )
}

private func stripControlTokensForStream(_ text: String) -> String {
    var result = text
    while let start = result.range(of: "<|"),
          let end = result.range(of: "|>", range: start.upperBound..<result.endIndex) {
        result.removeSubrange(start.lowerBound..<end.upperBound)
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// A multi-turn conversation with automatic history, multimodal support, and tool calling.
///
/// Uses `OpaquePointer?` directly (like PhoneClaw) for the C API pointer.
/// All operations are synchronous.
///
/// ```swift
/// let conversation = try engine.createConversation()
/// let response = try conversation.send("Hello!")
/// conversation.close()
/// ```
public final class LMConversation: @unchecked Sendable {

    private let engine: LMEngine
    private var cConversation: OpaquePointer?
    private let config: ConversationConfiguration
    private let queue = DispatchQueue(label: "com.litertlm.conversation", qos: .userInitiated)

    private var pendingSystemPrompt: String?

    public private(set) var history: [Message] = []

    init(engine: LMEngine, cConversation: OpaquePointer, configuration: ConversationConfiguration) {
        self.engine = engine
        self.cConversation = cConversation
        self.config = configuration
        self.pendingSystemPrompt = configuration.systemPrompt
    }

    deinit {
        close()
    }

    public var isActive: Bool { cConversation != nil }

    /// Close the conversation and release resources.
    public func close() {
        if let conversation = cConversation {
            litert_lm_conversation_delete(conversation)
            cConversation = nil
        }
        history.removeAll()
    }

    /// Cancel an in-progress generation.
    public func cancel() {
        guard let conversation = cConversation else { return }
        litert_lm_conversation_cancel_process(conversation)
    }

    // MARK: - Send Message

    /// Send a text message.
    public func send(_ text: String) async throws -> String {
        try await send(text, images: [], audio: [])
    }

    /// Send a multimodal message with optional images and audio.
    public func send(
        _ text: String,
        images: [Data] = [],
        audio: [Data] = [],
        audioFormat: AudioFormat = .wav
    ) async throws -> String {
        guard let conversation = cConversation else {
            throw LiteRTLMError.noActiveConversation
        }

        let effectiveText = consumePendingSystemPrompt(prefixing: text)
        let messageJSON = try buildMessageJSON(text: effectiveText, images: images, audio: audio)

        var contentParts: [Content] = [.text(text)]
        for img in images { contentParts.append(.image(img)) }
        for aud in audio { contentParts.append(.audio(aud, format: audioFormat)) }
        history.append(Message(role: .user, content: contentParts))

        let rawResponse: String = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let jsonResponse = litert_lm_conversation_send_message(
                    conversation, messageJSON, nil
                ) else {
                    continuation.resume(throwing: LiteRTLMError.emptyResponse)
                    return
                }
                defer { litert_lm_json_response_delete(jsonResponse) }

                guard let cStr = litert_lm_json_response_get_string(jsonResponse) else {
                    continuation.resume(throwing: LiteRTLMError.emptyResponse)
                    return
                }

                continuation.resume(returning: String(cString: cStr))
            }
        }

        NSLog("[LMConversation] 📥 RAW response (\(rawResponse.count) chars): \(rawResponse.prefix(1000))")

        if let toolCall = parseToolCall(rawResponse) {
            NSLog("[LMConversation] ✅ Tool call detected: \(toolCall.name) args=\(toolCall.arguments)")
            history.append(.model(rawResponse))
            return try await handleToolCall(toolCall, conversation: conversation)
        }

        NSLog("[LMConversation] ❌ No tool call detected in response")

        let response = Self.parseResponseJSON(rawResponse)
        history.append(.model(response))
        return response
    }

    /// Send a message and stream the response token by token.
    /// In automatic tool mode, tool calls are detected at stream end,
    /// executed internally, and the follow-up response is streamed.
    public func sendStream(
        _ text: String,
        images: [Data] = [],
        audio: [Data] = [],
        audioFormat: AudioFormat = .wav
    ) throws -> TokenStream {
        guard let conversation = cConversation else {
            throw LiteRTLMError.noActiveConversation
        }

        let effectiveText = consumePendingSystemPrompt(prefixing: text)
        let messageJSON = try buildMessageJSON(text: effectiveText, images: images, audio: audio)

        let contentParts: [Content] = {
            var parts: [Content] = [.text(text)]
            for img in images { parts.append(.image(img)) }
            for aud in audio { parts.append(.audio(aud, format: audioFormat)) }
            return parts
        }()
        history.append(Message(role: .user, content: contentParts))

        return TokenStream(AsyncThrowingStream { continuation in
                final class StreamCtx {
                    let cont: AsyncThrowingStream<String, Error>.Continuation
                    var lastText = ""
                    var fullText = ""
                    init(_ c: AsyncThrowingStream<String, Error>.Continuation) { self.cont = c }
                }
                let ctx = StreamCtx(continuation)
                let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()

                let result = litert_lm_conversation_send_message_stream(
                    conversation, messageJSON, nil,
                    { callbackData, chunk, isFinal, errorMsg in
                        guard let callbackData else { return }
                        let ctx = Unmanaged<StreamCtx>.fromOpaque(callbackData)
                        let state = ctx.takeUnretainedValue()

                        if let errorMsg {
                            state.cont.finish(
                                throwing: LiteRTLMError.streamingError(message: String(cString: errorMsg)))
                            ctx.release()
                            return
                        }

                        if let chunk {
                            let raw = String(cString: chunk)
                            if !raw.isEmpty {
                                let currentText = LMConversation.parseResponseJSON(raw)
                                state.fullText = currentText

                                if currentText.count > state.lastText.count,
                                   currentText.hasPrefix(state.lastText) {
                                    let delta = String(currentText.dropFirst(state.lastText.count))
                                    state.cont.yield(delta)
                                } else if currentText != state.lastText {
                                    state.cont.yield(currentText)
                                }
                                state.lastText = currentText
                            }
                        }

                        if isFinal {
                            // Check for tool calls before finishing the stream
                            var detectedToolCall: ToolCallInfo?
                            if let tc = tryParseToolCallForStream(state.fullText) {
                                detectedToolCall = tc
                            } else {
                                let cleaned = stripControlTokensForStream(state.fullText)
                                if cleaned != state.fullText, let tc = tryParseToolCallForStream(cleaned) {
                                    detectedToolCall = tc
                                }
                            }

                            if let tc = detectedToolCall {
                                // Yield marker token for proxy to detect
                                let argsJson: String
                                if let argsData = try? JSONSerialization.data(withJSONObject: tc.arguments),
                                   let parsed = String(data: argsData, encoding: .utf8) {
                                    argsJson = parsed
                                } else {
                                    argsJson = "{}"
                                }
                                let marker = "__TOOL_CALL__\(tc.name)__\(argsJson)__"
                                state.cont.yield(marker)
                            }

                            state.cont.finish()
                            ctx.release()
                        }
                    },
                    ctxPtr
                )

                if result != 0 {
                    Unmanaged<StreamCtx>.fromOpaque(ctxPtr)
                        .takeRetainedValue()
                        .cont
                        .finish(throwing: LiteRTLMError.streamingError(
                            message: "Stream initiation failed with code \(result)"))
                }
        })
    }

    /// Handle a tool call detected during streaming.
    /// Sends the tool result back to the conversation and returns the final model response.
    public func handleStreamToolCall(_ name: String, arguments: [String: Any]) async throws -> String {
        guard let conversation = cConversation else {
            throw LiteRTLMError.noActiveConversation
        }

        // Find and execute the tool
        guard let tool = config.tools.first(where: { $0.name == name }) else {
            return "Error: Unknown tool '\(name)'"
        }

        let result = try await tool.execute(arguments)
        let resultJSON = try JSONSerialization.data(withJSONObject: result, options: [])
        let resultStr = String(data: resultJSON, encoding: .utf8) ?? "{}"

        let toolResponse: [String: Any] = [
            "role": "user",
            "content": [["type": "text", "text": resultStr]],
        ]
        let toolData = try JSONSerialization.data(withJSONObject: toolResponse)
        guard let toolMessage = String(data: toolData, encoding: .utf8) else {
            throw LiteRTLMError.internalError("Failed to encode tool result as JSON")
        }

        guard let jsonResponse = litert_lm_conversation_send_message(
            conversation, toolMessage, nil
        ) else {
            throw LiteRTLMError.emptyResponse
        }
        defer { litert_lm_json_response_delete(jsonResponse) }

        guard let cStr = litert_lm_json_response_get_string(jsonResponse) else {
            throw LiteRTLMError.emptyResponse
        }

        return Self.parseResponseJSON(String(cString: cStr))
    }

    // MARK: - Tool Handling

    private struct ToolCall {
        let name: String
        let arguments: [String: Any]
    }

    private func parseToolCall(_ response: String) -> ToolCall? {
        if let tc = Self.tryParseToolCall(response) {
            return tc
        }
        // Only strip control tokens as fallback — Gemma 4 tool calls are caught above
        let cleaned = Self.stripControlTokens(response)
        if cleaned != response, let tc = Self.tryParseToolCall(cleaned) {
            return tc
        }
        return nil
    }

    private static func tryParseToolCall(_ str: String) -> ToolCall? {
        guard let data = str.data(using: .utf8) else {
            return parseGemma4ToolCall(str).map { ToolCall(name: $0.name, arguments: $0.arguments) }
        }

        // If the string is valid JSON, parse it and try Gemma 4 on extracted text.
        // Do NOT call parseGemma4ToolCall on the raw JSON string — backslash-escaped
        // quotes like \"Berlin\" break args parsing.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let tc = extractToolCall(from: json) {
                return tc
            }

            for key in ["text", "content"] {
                if let inner = json[key] as? String {
                    if let tc = parseGemma4ToolCall(inner).map({ ToolCall(name: $0.name, arguments: $0.arguments) }) {
                        return tc
                    }
                    let innerCleaned = stripControlTokens(inner)
                    if let innerData = innerCleaned.data(using: .utf8),
                       let innerJson = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
                        if let tc = extractToolCall(from: innerJson) {
                            return tc
                        }
                    }
                }
            }

            if let content = json["content"] as? [[String: Any]] {
                for part in content {
                    if let inner = part["text"] as? String {
                        if let tc = parseGemma4ToolCall(inner).map({ ToolCall(name: $0.name, arguments: $0.arguments) }) {
                            return tc
                        }
                        let innerCleaned = stripControlTokens(inner)
                        if let innerData = innerCleaned.data(using: .utf8),
                           let innerJson = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any],
                           let tc = extractToolCall(from: innerJson) {
                            return tc
                        }
                    }
                }
            }

            return nil
        }

        // Not JSON — try Gemma 4 on the raw string (e.g., plain text from streaming)
        return parseGemma4ToolCall(str).map { ToolCall(name: $0.name, arguments: $0.arguments) }
    }

    private static func extractToolCall(from json: [String: Any]) -> ToolCall? {
        if let funcCall = json["function_call"] as? [String: Any],
           let name = funcCall["name"] as? String {
            return ToolCall(name: name, arguments: extractArguments(funcCall["arguments"]))
        }

        if let toolCalls = json["tool_calls"] as? [[String: Any]],
           let first = toolCalls.first,
           let function = first["function"] as? [String: Any],
           let name = function["name"] as? String {
            return ToolCall(name: name, arguments: extractArguments(function["arguments"]))
        }

        return nil
    }

    private static func extractArguments(_ value: Any?) -> [String: Any] {
        var dict: [String: Any]?
        if let d = value as? [String: Any] {
            dict = d
        } else if let str = value as? String,
                  let data = str.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = d
        }
        guard let dict else { return [:] }

        var cleaned: [String: Any] = [:]
        for (key, value) in dict {
            if let str = value as? String {
                cleaned[key] = stripControlTokens(str)
            } else {
                cleaned[key] = value
            }
        }
        return cleaned
    }

    private static func stripControlTokens(_ text: String) -> String {
        var result = text
        while let start = result.range(of: "<|"),
              let end = result.range(of: "|>", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleToolCall(_ toolCall: ToolCall, conversation: OpaquePointer) async throws -> String {
        NSLog("[LMConversation] 🔧 handleToolCall: \(toolCall.name), mode=\(config.toolExecutionMode)")

        guard config.toolExecutionMode == .automatic else {
            let dict: [String: Any] = ["function_call": ["name": toolCall.name, "arguments": toolCall.arguments]]
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        }

        guard let tool = config.tools.first(where: { $0.name == toolCall.name }) else {
            NSLog("[LMConversation] ⚠️ Unknown tool '\(toolCall.name)', available: \(config.tools.map(\.name))")
            return "Error: Unknown tool '\(toolCall.name)'"
        }

        NSLog("[LMConversation] 🔧 Executing tool '\(toolCall.name)' with args: \(toolCall.arguments)")
        let result = try await tool.execute(toolCall.arguments)
        NSLog("[LMConversation] 🔧 Tool result: \(result)")
        let resultJSON = try JSONSerialization.data(withJSONObject: result, options: [])
        let resultStr = String(data: resultJSON, encoding: .utf8) ?? "{}"

        let toolResponse: [String: Any] = [
            "role": "user",
            "content": [["type": "text", "text": resultStr]],
        ]
        let toolData = try JSONSerialization.data(withJSONObject: toolResponse)
        guard let toolMessage = String(data: toolData, encoding: .utf8) else {
            throw LiteRTLMError.internalError("Failed to encode tool result as JSON")
        }

        NSLog("[LMConversation] 🔧 Sending tool result (\(toolMessage.count) chars): \(toolMessage.prefix(500))")

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let jsonResponse = litert_lm_conversation_send_message(
                    conversation, toolMessage, nil
                ) else {
                    continuation.resume(throwing: LiteRTLMError.emptyResponse)
                    return
                }
                defer { litert_lm_json_response_delete(jsonResponse) }

                guard let cStr = litert_lm_json_response_get_string(jsonResponse) else {
                    continuation.resume(throwing: LiteRTLMError.emptyResponse)
                    return
                }

                let rawResponse = String(cString: cStr)
                NSLog("[LMConversation] 🔧 Model response after tool (\(rawResponse.count) chars): \(rawResponse.prefix(500))")
                continuation.resume(returning: Self.parseResponseJSON(rawResponse))
            }
        }
    }

    // MARK: - Message Building

    private func consumePendingSystemPrompt(prefixing text: String) -> String {
        guard let prompt = pendingSystemPrompt else { return text }
        pendingSystemPrompt = nil
        var fullPrompt = prompt
        if !config.tools.isEmpty {
            let toolNames = config.tools.map { $0.name }.joined(separator: ", ")
            fullPrompt += "\n\nYou have access to the following tools: \(toolNames). When the user asks something that requires a tool, use it instead of saying you cannot help."
        }
        return "\(fullPrompt)\n\n---\n\n\(text)"
    }

    private func buildMessageJSON(text: String, images: [Data], audio: [Data]) throws -> String {
        let tmpDir = FileManager.default.temporaryDirectory
        var parts: [[String: Any]] = []

        for (i, imageData) in images.enumerated() {
            let prepared = try ImageUtilities.prepareForVision(imageData, maxDimension: config.maxImageDimension)
            let path = tmpDir.appendingPathComponent("litertlm_img_\(i).jpg")
            try prepared.write(to: path)
            parts.append(["type": "image", "path": path.path])
        }
        for (i, audioData) in audio.enumerated() {
            let path = tmpDir.appendingPathComponent("litertlm_audio_\(i).wav")
            try audioData.write(to: path)
            parts.append(["type": "audio", "path": path.path])
        }
        parts.append(["type": "text", "text": text])

        let json: [String: Any] = ["role": "user", "content": parts]
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return String(data: data, encoding: .utf8) ?? text
    }

    // MARK: - Response Parsing

    static func parseResponseJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        if let text = json["text"] as? String { return text }
        if let content = json["content"] as? [[String: Any]] {
            let texts = content.compactMap { $0["text"] as? String }
            if !texts.isEmpty { return texts.joined(separator: "\n") }
        }
        if let content = json["content"] as? String { return content }
        if let parts = json["parts"] as? [[String: Any]],
           let firstText = parts.first?["text"] as? String { return firstText }
        return raw
    }

    // MARK: - Benchmark

    public func benchmarkInfo() -> BenchmarkInfo? {
        guard let conversation = cConversation else { return nil }
        guard let info = litert_lm_conversation_get_benchmark_info(conversation) else { return nil }
        defer { litert_lm_benchmark_info_delete(info) }
        return BenchmarkInfo.from(cInfo: info)
    }
}
