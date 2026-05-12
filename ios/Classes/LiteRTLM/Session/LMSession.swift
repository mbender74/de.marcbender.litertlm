import CLiteRTLM
import UIKit
import TitaniumKit

/// A generation session with KV-cache persistence for multi-turn text generation.
///
/// Uses `OpaquePointer?` directly (like PhoneClaw) for the C API pointer.
/// All operations are synchronous.
///
/// ```swift
/// let session = try engine.createSession()
/// let response = try session.generate("Hello!")
/// session.close()
/// ```
public final class LMSession: @unchecked Sendable {

    private let engine: LMEngine
    private var cSession: OpaquePointer?
    private let sessionConfig: SessionConfiguration

    init(engine: LMEngine, cSession: OpaquePointer, configuration: SessionConfiguration) {
        self.engine = engine
        self.cSession = cSession
        self.sessionConfig = configuration
    }

    deinit {
        close()
    }

    public var isActive: Bool { cSession != nil }

    /// Close the session and release KV-cache memory.
    public func close() {
        if let session = cSession {
            litert_lm_session_delete(session)
            cSession = nil
        }
    }

    // MARK: - Text Generation

    /// Generate a complete response (blocking).
    public func generate(_ prompt: String, template: PromptTemplate = .gemma) throws -> String {
        guard let session = cSession else {
            throw LiteRTLMError.noActiveSession
        }

        let formatted = template.formatSingle(prompt)

        var input = InputData(
            type: kInputText,
            data: UnsafeRawPointer((formatted as NSString).utf8String!),
            size: strlen((formatted as NSString).utf8String!)
        )

        guard let responses = litert_lm_session_generate_content(
            session, &input, 1
        ) else {
            throw LiteRTLMError.emptyResponse
        }
        defer { litert_lm_responses_delete(responses) }

        let count = litert_lm_responses_get_num_candidates(responses)
        guard count > 0,
              let text = litert_lm_responses_get_response_text_at(responses, 0) else {
            throw LiteRTLMError.emptyResponse
        }

        return String(cString: text)
    }

    /// Generate a response as a token stream.
    public func generateStream(
        _ prompt: String,
        template: PromptTemplate = .gemma
    ) -> TokenStream {
        let formatted = template.formatSingle(prompt)
        let session = self.cSession

        return TokenStream(AsyncThrowingStream { continuation in
            guard let session else {
                continuation.finish(throwing: LiteRTLMError.noActiveSession)
                return
            }

            final class StreamContext {
                let continuation: AsyncThrowingStream<String, Error>.Continuation
                init(_ c: AsyncThrowingStream<String, Error>.Continuation) {
                    self.continuation = c
                }
            }
            let ctx = StreamContext(continuation)
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()

            guard let cStr = (formatted as NSString).utf8String else {
                Unmanaged<StreamContext>.fromOpaque(ctxPtr)
                    .takeRetainedValue()
                    .continuation
                    .finish(throwing: LiteRTLMError.invalidInput(detail: "Failed to encode prompt as UTF-8"))
                return
            }
            var input = InputData(
                type: kInputText,
                data: UnsafeRawPointer(cStr),
                size: strlen(cStr)
            )

            let result = litert_lm_session_generate_content_stream(
                session,
                &input,
                1,
                { callbackData, chunk, isFinal, errorMsg in
                    guard let callbackData else { return }
                    let ctx = Unmanaged<StreamContext>.fromOpaque(callbackData)

                    if let errorMsg {
                        let msg = String(cString: errorMsg)
                        ctx.takeUnretainedValue().continuation.finish(
                            throwing: LiteRTLMError.streamingError(message: msg))
                        ctx.release()
                        return
                    }

                    if let chunk {
                        let str = String(cString: chunk)
                        if !str.isEmpty {
                            ctx.takeUnretainedValue().continuation.yield(str)
                        }
                    }

                    if isFinal {
                        ctx.takeUnretainedValue().continuation.finish()
                        ctx.release()
                    }
                },
                ctxPtr
            )

            if result != 0 {
                Unmanaged<StreamContext>.fromOpaque(ctxPtr)
                    .takeRetainedValue()
                    .continuation
                    .finish(throwing: LiteRTLMError.streamingError(
                        message: "Stream initiation failed with code \(result)"))
            }
        })
    }

    // MARK: - Multimodal Generation

    /// Generate from multimodal inputs (text + images + audio).
    public func generate(
        text: String,
        images: [Data] = [],
        audio: [Data] = [],
        template: PromptTemplate = .gemma
    ) throws -> String {
        guard let session = cSession else {
            throw LiteRTLMError.noActiveSession
        }

        let formatted = template.formatSingle(text)

        var inputs: [InputData] = []
        var pinnedData: [NSData] = []

        // Add images
        for imageData in images {
            let prepared = (try? ImageUtilities.prepareForVision(imageData, maxDimension: 1024)) ?? imageData
            let nsData = prepared as NSData
            pinnedData.append(nsData)
            inputs.append(InputData(type: kInputImage, data: nsData.bytes, size: nsData.length))
            inputs.append(InputData(type: kInputImageEnd, data: nil, size: 0))
        }

        // Add audio
        for audioData in audio {
            let nsData = audioData as NSData
            pinnedData.append(nsData)
            inputs.append(InputData(type: kInputAudio, data: nsData.bytes, size: nsData.length))
            inputs.append(InputData(type: kInputAudioEnd, data: nil, size: 0))
        }

        // Add text
        let cText = (formatted as NSString).utf8String!
        inputs.append(InputData(type: kInputText, data: UnsafeRawPointer(cText), size: strlen(cText)))

        guard let responses = litert_lm_session_generate_content(
            session, &inputs, inputs.count
        ) else {
            throw LiteRTLMError.emptyResponse
        }
        defer { litert_lm_responses_delete(responses) }

        let count = litert_lm_responses_get_num_candidates(responses)
        guard count > 0,
              let text = litert_lm_responses_get_response_text_at(responses, 0) else {
            throw LiteRTLMError.emptyResponse
        }

        withExtendedLifetime(pinnedData) {}

        return String(cString: text)
    }

    // MARK: - Benchmark

    /// Retrieve benchmark metrics (requires `benchmarkEnabled` in engine config).
    public func benchmarkInfo() -> BenchmarkInfo? {
        guard let session = cSession else { return nil }
        guard let info = litert_lm_session_get_benchmark_info(session) else { return nil }
        defer { litert_lm_benchmark_info_delete(info) }
        return BenchmarkInfo.from(cInfo: info)
    }
}
