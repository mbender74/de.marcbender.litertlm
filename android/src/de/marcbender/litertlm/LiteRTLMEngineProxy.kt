package de.marcbender.litertlm

import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.*
import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log
import org.appcelerator.titanium.TiApplication
import java.io.File
import java.util.concurrent.Executors

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMEngineProxy : KrollProxy() {

    companion object {
        private const val LCAT = "LiteRTLMEngineProxy"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    internal var modelPath: String = ""
    internal var backend: String = "CPU"
    internal var maxTokens: Int = -1
    internal var cacheDir: String? = null
    internal var benchmarkEnabled: Boolean = false
    internal var visionBackend: String? = null
    internal var audioBackend: String? = null

    private var engine: Engine? = null
    private var configProxy: LiteRTLMEngineConfiguration? = null
    private var moduleRef: TitaniumLiteRTLMModule? = null

    internal var _status: String = "notLoaded"

    @Kroll.getProperty
    fun getStatus(): String = _status

    @Kroll.setProperty
    fun setStatus(value: String) {
        _status = value
        setProperty("status", value)
    }

    @Kroll.getProperty
    fun getIsReady(): Boolean = engine?.isInitialized() == true

    @Kroll.getProperty
    fun getLastError(): String? = null

    fun setConfigProxy(proxy: LiteRTLMEngineConfiguration) {
        configProxy = proxy
        modelPath = proxy.modelPath
        backend = proxy.backend
        maxTokens = proxy.maxTokens
        cacheDir = proxy.cacheDir
        benchmarkEnabled = proxy.benchmarkEnabled
        visionBackend = proxy.visionBackend
        audioBackend = proxy.audioBackend
    }

    fun loadEngine(module: TitaniumLiteRTLMModule) {
        moduleRef = module
        Log.d(LCAT, "loadEngine: modelPath=$modelPath backend=$backend")

        try {
            NativeLibraryLoader.load()
            Log.d(LCAT, "Native library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(LCAT, "Failed to load native library: ${e.message}")
            _status = "error"
            throw e
        }

        Engine.setNativeMinLogSeverity(LogSeverity.VERBOSE)

        val resolvedPath = resolveModelPath(modelPath)
        Log.d(LCAT, "Resolved model path: $resolvedPath")

        val file = File(resolvedPath)
        if (!file.exists()) {
            throw RuntimeException("Model file not found: $resolvedPath")
        }

        val backendObj: Backend = when (backend.uppercase()) {
            "GPU" -> Backend.GPU()
            else -> Backend.CPU()
        }

        val visionBackendObj: Backend? = visionBackend?.let {
            when (it.uppercase()) {
                "GPU" -> Backend.GPU()
                "NPU" -> Backend.NPU()
                else -> Backend.CPU()
            }
        }

        val audioBackendObj: Backend? = audioBackend?.let {
            when (it.uppercase()) {
                "GPU" -> Backend.GPU()
                "NPU" -> Backend.NPU()
                else -> Backend.CPU()
            }
        }

        val config = EngineConfig(
            modelPath = resolvedPath,
            backend = backendObj,
            visionBackend = visionBackendObj,
            audioBackend = audioBackendObj,
            maxNumTokens = if (maxTokens > 0) maxTokens else null,
            cacheDir = cacheDir ?: resolvedPath.substringBeforeLast("/")
        )

        val eng = Engine(config)
        eng.initialize()

        this.engine = eng
        _status = "ready"
        Log.d(LCAT, "Engine loaded successfully")
    }

    @Kroll.method
    fun load() {
        _status = "loading"
        setProperty("status", "loading")
        fireEvent("statuschange", hashMapOf("status" to "loading"))

        backgroundExecutor.execute {
            try {
                val module = moduleRef ?: TiApplication.getInstance().let {
                    TitaniumLiteRTLMModule()
                }
                loadEngine(module)
                mainHandler.post {
                    setProperty("status", "ready")
                    fireEvent("statuschange", hashMapOf("status" to "ready"))
                    fireEvent("ready", hashMapOf<String, Any>())
                }
            } catch (e: Exception) {
                _status = "error"
                mainHandler.post {
                    setProperty("status", "error")
                    fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }
    }

    @Kroll.method
    fun unload() = unloadEngine()

    @Kroll.method
    fun unloadEngine() {
        try {
            engine?.close()
        } catch (e: Exception) {
            Log.e(LCAT, "Error unloading engine: ${e.message}")
        }
        engine = null
        _status = "notLoaded"
        mainHandler.post {
            setProperty("status", "notLoaded")
            fireEvent("statuschange", hashMapOf("status" to "notLoaded"))
        }
    }

    @Kroll.method
    fun createConversation(args: Any) {
        val configProxy = extractProxy<LiteRTLMConversationConfiguration>(args) ?: return
        createConversationWithConfig(args)
    }

    @Kroll.method
    fun createConversationWithConfig(args: Any) {
        val configProxy = extractProxy<LiteRTLMConversationConfiguration>(args) ?: return
        val toolProxies = configProxy.tools

        backgroundExecutor.execute {
            try {
                val eng = engine ?: throw RuntimeException("Engine not initialized")
                if (!eng.isInitialized()) throw RuntimeException("Engine not ready")

                val conversationConfig = buildConversationConfig(configProxy, eng)
                val conversation = eng.createConversation(conversationConfig)
                val proxy = LiteRTLMConversationProxy()
                proxy.setConversation(conversation, this, configProxy, toolProxies)

                mainHandler.post {
                    setProperty("conversation", proxy)
                    // Fire on module-level (JS listens on litertlm module, not engine proxy)
                    moduleRef?.fireEvent("conversationcreated", hashMapOf("conversation" to proxy))
                        ?: fireEvent("conversationcreated", hashMapOf("conversation" to proxy))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    moduleRef?.fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                        ?: fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }
    }

    @Kroll.method
    fun createSession(args: Any) {
        val configProxy = extractProxy<LiteRTLMSessionConfiguration>(args) ?: return

        backgroundExecutor.execute {
            try {
                val eng = engine ?: throw RuntimeException("Engine not initialized")
                if (!eng.isInitialized()) throw RuntimeException("Engine not ready")

                val sessionConfig = buildSessionConfig(configProxy)
                val session = eng.createSession(sessionConfig)
                val proxy = LiteRTLMSessionProxy()
                proxy.setSession(session, this)

                mainHandler.post {
                    setProperty("session", proxy)
                    fireEvent("sessioncreated", hashMapOf("session" to proxy))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }
    }

    internal fun buildConversationConfig(
        proxy: LiteRTLMConversationConfiguration,
        engine: Engine
    ): ConversationConfig {
        val samplerConfig = buildSamplerConfig(proxy.samplerType, proxy.maxOutputTokens)
        val systemInstruction = proxy.systemPrompt?.let { Contents.of(it) }
        val tools = proxy.tools.map { com.google.ai.edge.litertlm.tool(it.toOpenApiTool()) }
        val toolExecutionMode = proxy.toolExecutionMode

        return ConversationConfig(
            systemInstruction = systemInstruction,
            tools = tools,
            samplerConfig = samplerConfig,
            automaticToolCalling = toolExecutionMode != "manual"
        )
    }

    internal fun buildSessionConfig(proxy: LiteRTLMSessionConfiguration): SessionConfig {
        val samplerConfig = buildSamplerConfig(proxy.samplerType, proxy.maxOutputTokens)
        return SessionConfig(samplerConfig = samplerConfig)
    }

    private fun buildSamplerConfig(samplerType: String?, maxOutputTokens: Int): SamplerConfig? {
        return when (samplerType) {
            "greedy" -> SamplerConfig(topK = 1, topP = 1.0, temperature = 0.0)
            "creative" -> SamplerConfig(topK = 100, topP = 0.98, temperature = 1.0)
            else -> SamplerConfig(topK = 40, topP = 0.95, temperature = 0.7)
        }
    }

    private fun resolveModelPath(path: String): String {
        if (path.startsWith("/")) return path
        val dl = moduleRef?.getDownloader()
        val basePath = dl?.getModelsDirectory() ?: let {
            val app = TiApplication.getInstance()
            File(app.filesDir, "models").absolutePath
        }
        return File(basePath, path).absolutePath
    }

    @Suppress("UNCHECKED_CAST")
    private inline fun <reified T : KrollProxy> extractProxy(args: Any): T? {
        return when (args) {
            is T -> args
            is ArrayList<*> -> args.firstOrNull() as? T
            else -> null
        }
    }
}