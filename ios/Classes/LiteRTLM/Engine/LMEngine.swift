
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

/// Actor-based LLM engine managing the full lifecycle of a LiteRT-LM model.
///
/// ```swift
/// let config = EngineConfiguration(modelPath: modelURL).backend(.gpu)
/// let engine = LMEngine(configuration: config)
/// try await engine.load()
/// ```
public actor LMEngine {

    public private(set) var status: EngineStatus = .notLoaded

    public var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    public let configuration: EngineConfiguration

    nonisolated(unsafe) var cEngine: OpaquePointer?

    public init(configuration: EngineConfiguration) {
        self.configuration = configuration
    }

    deinit {
        if let engine = cEngine {
            litert_lm_engine_delete(engine)
        }
    }

    /// Load the model into memory.
    public func load() async throws {
        guard !isReady else { throw LiteRTLMError.engineAlreadyLoaded }

        let config = configuration
        let modelPath = config.modelPath.path

        guard FileManager.default.fileExists(atPath: modelPath) else {
            let err = LiteRTLMError.modelNotFound(path: modelPath)
            status = .error(err)
            throw err
        }

        status = .loading

        // Set log level to INFO to get maximum debugging output from CLiteRTLM
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

    func requireReady() throws -> OpaquePointer {
        guard let engine = cEngine else {
            throw LiteRTLMError.engineNotReady
        }
        return engine
    }
}
