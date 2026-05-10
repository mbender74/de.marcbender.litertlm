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
    public func createConversation(configuration: ConversationConfiguration) throws -> LMConversation {
        NSLog("[DEBUG] LMEngine: createConversation START")
        guard let engine = cEngine else {
            NSLog("[DEBUG] LMEngine: createConversation FAILED - cEngine is nil")
            throw LiteRTLMError.engineNotReady
        }
        NSLog("[DEBUG] LMEngine: cEngine OK")

        guard let sessionConfig = litert_lm_session_config_create() else {
            NSLog("[DEBUG] LMEngine: createConversation FAILED - session_config_create returned NULL")
            throw LiteRTLMError.conversationCreationFailed
        }
        defer { litert_lm_session_config_delete(sessionConfig) }
        NSLog("[DEBUG] LMEngine: session_config OK")

        litert_lm_session_config_set_max_output_tokens(sessionConfig, configuration.maxOutputTokens)
        NSLog("[DEBUG] LMEngine: max_output_tokens=\(configuration.maxOutputTokens)")

        var samplerParams = configuration.sampler.toCParams()
        litert_lm_session_config_set_sampler_params(sessionConfig, &samplerParams)
        NSLog("[DEBUG] LMEngine: sampler_params OK")

        // Build tools JSON if any
        let toolsJSON: String? = configuration.tools.isEmpty ? nil : {
            let schemas = configuration.tools.map { $0.toJSONSchema() }
            if let data = try? JSONSerialization.data(withJSONObject: schemas),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return nil
        }()
        NSLog("[DEBUG] LMEngine: tools=\(configuration.tools.count), toolsJSON=\(toolsJSON != nil ? "present" : "nil")")

        // New API: create empty config, then set properties via setters
        guard let convConfig = litert_lm_conversation_config_create() else {
            NSLog("[DEBUG] LMEngine: createConversation FAILED - conversation_config_create returned NULL")
            throw LiteRTLMError.conversationCreationFailed
        }
        NSLog("[DEBUG] LMEngine: conversation_config OK")

        // Set session config
        litert_lm_conversation_config_set_session_config(convConfig, sessionConfig)
        NSLog("[DEBUG] LMEngine: set session_config OK")

        // PhoneClaw only calls set_system_message when there's actual content
        // Omit when nil to avoid potential API issues

        // PhoneClaw only calls set_tools when there's actual content
        // Use withCString like PhoneClaw does
        if let toolsJSON = toolsJSON {
            toolsJSON.withCString { litert_lm_conversation_config_set_tools(convConfig, $0) }
        }
        NSLog("[DEBUG] LMEngine: set tools OK")

        // Try with NULL config first (uses defaults) – works on this LiteRTLM version
        guard let cConversation = litert_lm_conversation_create(engine, nil) else {
            NSLog("[DEBUG] LMEngine: createConversation FAILED - litert_lm_conversation_create(NULL) returned NULL")
            litert_lm_conversation_config_delete(convConfig)
            throw LiteRTLMError.conversationCreationFailed
        }
        litert_lm_conversation_config_delete(convConfig)
        litert_lm_session_config_delete(sessionConfig)
        NSLog("[DEBUG] LMEngine: createConversation SUCCESS (NULL config)")

        // Note: Custom config params (maxOutputTokens, sampler, systemPrompt, tools)
        // are not applied because this LiteRTLM version only accepts NULL config.
        // The C API's builder-style config setters seem to be broken.
        // Future: Upgrade LiteRTLM or switch to Session API for custom params.

        return LMConversation(engine: self, cConversation: cConversation, configuration: configuration)
    }
}
