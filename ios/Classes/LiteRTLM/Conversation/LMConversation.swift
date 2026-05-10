import CLiteRTLM
import UIKit
import TitaniumKit
import os.log
private let logger = Logger(subsystem: "com.litertlm", category: "conversation")

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

        guard let jsonResponse = litert_lm_conversation_send_message(
            conversation, messageJSON, nil
        ) else {
            throw LiteRTLMError.emptyResponse
        }
        defer { litert_lm_json_response_delete(jsonResponse) }

        guard let cStr = litert_lm_json_response_get_string(jsonResponse) else {
            throw LiteRTLMError.emptyResponse
        }

        let rawResponse = String(cString: cStr)

        if let toolCall = parseToolCall(rawResponse) {
            history.append(.model(rawResponse))
            return try await handleToolCall(toolCall, conversation: conversation)
        }

        let response = Self.parseResponseJSON(rawResponse)
        history.append(.model(response))
        return response
    }

    /// Send a message and stream the response token by token.
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

        return TokenStream(AsyncThrowingStream { continuation in
                final class StreamCtx {
                    let cont: AsyncThrowingStream<String, Error>.Continuation
                    var lastText = ""
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

    // MARK: - Tool Handling

    private struct ToolCall {
        let name: String
        let arguments: [String: Any]
    }

    private func parseToolCall(_ response: String) -> ToolCall? {
        if let tc = Self.tryParseToolCall(response) {
            return tc
        }
        let cleaned = Self.stripControlTokens(response)
        if cleaned != response, let tc = Self.tryParseToolCall(cleaned) {
            return tc
        }
        return nil
    }

    private static func tryParseToolCall(_ str: String) -> ToolCall? {
        guard let data = str.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let tc = extractToolCall(from: json) {
            return tc
        }

        for key in ["text", "content"] {
            if let inner = json[key] as? String {
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
        guard config.toolExecutionMode == .automatic else {
            let dict: [String: Any] = ["function_call": ["name": toolCall.name, "arguments": toolCall.arguments]]
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        }

        guard let tool = config.tools.first(where: { $0.name == toolCall.name }) else {
            return "Error: Unknown tool '\(toolCall.name)'"
        }

        let result = try await tool.execute(toolCall.arguments)
        let resultJSON = try JSONSerialization.data(withJSONObject: result, options: [])
        let resultStr = String(data: resultJSON, encoding: .utf8) ?? "{}"

        let toolResponse: [String: Any] = [
            "role": "tool",
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

    // MARK: - Message Building

    private func consumePendingSystemPrompt(prefixing text: String) -> String {
        guard let prompt = pendingSystemPrompt else { return text }
        pendingSystemPrompt = nil
        return "\(prompt)\n\n---\n\n\(text)"
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
