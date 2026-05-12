import CLiteRTLM
import UIKit
import TitaniumKit

/// The lifecycle state of the engine.
public enum EngineStatus: Sendable {
    case notLoaded
    case loading
    case ready
    case error(LiteRTLMError)
}

/// LLM engine managing the full lifecycle of a LiteRT-LM model.
///
/// Uses `OpaquePointer?` directly (like PhoneClaw) for all C API pointers.
/// No actor, no Swift concurrency overhead – all operations are synchronous.
///
/// ```swift
/// let config = EngineConfiguration(modelPath: modelURL).backend(.gpu)
/// let engine = LMEngine(configuration: config)
/// engine.load()
/// ```
public final class LMEngine: @unchecked Sendable {

    public private(set) var status: EngineStatus = .notLoaded

    public var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    public let configuration: EngineConfiguration

    /// Raw C engine pointer
    private var cEngine: OpaquePointer?

    public init(configuration: EngineConfiguration) {
        self.configuration = configuration
    }

    deinit {
        if let engine = cEngine {
            litert_lm_engine_delete(engine)
        }
    }

    /// Load the model into memory.
    public func load() throws {
        guard !isReady else { throw LiteRTLMError.engineAlreadyLoaded }

        let config = configuration
        let modelPath = config.modelPath.path

        guard FileManager.default.fileExists(atPath: modelPath) else {
            let err = LiteRTLMError.modelNotFound(path: modelPath)
            status = .error(err)
            throw err
        }

        status = .loading

        // Set log level to VERBOSE
        litert_lm_set_min_log_level(0)

        // Convert Swift strings to null-terminated C strings
        let cModelPath = (modelPath as NSString).utf8String!
        let cBackend = (config.primaryBackend.rawValue as NSString).utf8String!
        let visionBackendStr = config.visionBackend?.rawValue ?? "cpu"
        let audioBackendStr = config.audioBackend?.rawValue ?? "cpu"
        let cVisionBackend = (visionBackendStr as NSString).utf8String!
        let cAudioBackend = (audioBackendStr as NSString).utf8String!

        guard let settings = litert_lm_engine_settings_create(
            cModelPath,
            cBackend,
            cVisionBackend,
            cAudioBackend
        ) else {
            let err = LiteRTLMError.engineCreationFailed(reason: "Failed to create engine settings")
            status = .error(err)
            throw err
        }
        defer { litert_lm_engine_settings_delete(settings) }

        if let maxTokens = config.maxTokens {
            litert_lm_engine_settings_set_max_num_tokens(settings, Int32(maxTokens))
        }

        if let cacheDir = config.cacheDir {
            litert_lm_engine_settings_set_cache_dir(settings, (cacheDir.path as NSString).utf8String!)
        }

        if config.isBenchmarkEnabled {
            litert_lm_engine_settings_enable_benchmark(settings)
        }

        guard let engine = litert_lm_engine_create(settings) else {
            let err = LiteRTLMError.engineCreationFailed(reason: "litert_lm_engine_create returned NULL")
            status = .error(err)
            throw err
        }

        cEngine = engine
        status = .ready
    }

    /// Release the model from memory.
    public func unload() {
        if let engine = cEngine {
            litert_lm_engine_delete(engine)
            cEngine = nil
        }
        status = .notLoaded
    }

    /// Create a session with the given configuration.
    public func createSession(configuration: SessionConfiguration) throws -> LMSession {
        guard let engine = cEngine else {
            throw LiteRTLMError.engineNotReady
        }

        guard let sessionConfig = litert_lm_session_config_create() else {
            throw LiteRTLMError.sessionCreationFailed
        }
        defer { litert_lm_session_config_delete(sessionConfig) }

        litert_lm_session_config_set_max_output_tokens(sessionConfig, configuration.maxOutputTokens)

        var samplerParams = configuration.sampler.toCParams()
        litert_lm_session_config_set_sampler_params(sessionConfig, &samplerParams)

        guard let cSession = litert_lm_engine_create_session(engine, sessionConfig) else {
            throw LiteRTLMError.sessionCreationFailed
        }

        return LMSession(engine: self, cSession: cSession, configuration: configuration)
    }

    /// Create a conversation with the given configuration.
    ///
    /// Uses the 6-argument `litert_lm_conversation_config_create(engine, sessionConfig, systemMessage, tools, messages, constrainedDecoding)`.
    /// System prompt is passed as nil (Gemma 4 chat template has no system role – handled via pendingSystemPrompt).
    public func createConversation(configuration: ConversationConfiguration) throws -> LMConversation {
        guard let engine = cEngine else {
            throw LiteRTLMError.engineNotReady
        }

        // Step 1: Create session config
        guard let sessionConfig = litert_lm_session_config_create() else {
            throw LiteRTLMError.conversationCreationFailed
        }
        defer { litert_lm_session_config_delete(sessionConfig) }

        litert_lm_session_config_set_max_output_tokens(sessionConfig, configuration.maxOutputTokens)

        var samplerParams = configuration.sampler.toCParams()
        litert_lm_session_config_set_sampler_params(sessionConfig, &samplerParams)

        // Step 2: Build tools JSON if any
        let toolsJSON: String? = configuration.tools.isEmpty ? nil : {
            let schemas = configuration.tools.map { $0.toJSONSchema() }
            NSLog("[LMEngine] 🔧 Tools JSON schemas: \(schemas)")
            if let data = try? JSONSerialization.data(withJSONObject: schemas),
               let str = String(data: data, encoding: .utf8) {
                NSLog("[LMEngine] 🔧 Tools JSON string (\(str.count) chars): \(str.prefix(500))")
                return str
            }
            NSLog("[LMEngine] ⚠️ Failed to serialize tools JSON")
            return nil
        }()
        NSLog("[LMEngine] 🔧 enable_constrained_decoding=\(!configuration.tools.isEmpty), toolsJSON=\(toolsJSON != nil ? "present" : "nil")")

        // Step 3: Call 6-arg conversation config create
        // system_message_json: nil (Gemma 4 has no system role, C runtime drops it)
        // messages_json: nil (no pre-loaded messages)
        // enable_constrained_decoding: true when tools are present
        guard let convConfig = litert_lm_conversation_config_create(
            engine,
            sessionConfig,
            nil,          // system_message_json
            toolsJSON,    // tools_json (nil if no tools)
            nil,          // messages_json
            !configuration.tools.isEmpty  // enable_constrained_decoding
        ) else {
            throw LiteRTLMError.conversationCreationFailed
        }

        // Step 4: Create the conversation
        guard let cConversation = litert_lm_conversation_create(engine, convConfig) else {
            litert_lm_conversation_config_delete(convConfig)
            throw LiteRTLMError.conversationCreationFailed
        }

        litert_lm_conversation_config_delete(convConfig)
        return LMConversation(engine: self, cConversation: cConversation, configuration: configuration)
    }
}
