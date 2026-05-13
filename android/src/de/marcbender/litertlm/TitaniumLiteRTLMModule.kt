package de.marcbender.litertlm

import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.*
import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollModule
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log
import org.appcelerator.titanium.TiApplication
import java.io.File
import java.util.concurrent.Executors

@Kroll.module(name = "TitaniumLiteRTLM", id = "de.marcbender.litertlm")
class TitaniumLiteRTLMModule : KrollModule() {

    companion object {
        private const val LCAT = "TitaniumLiteRTLM"
        private var moduleRef: TitaniumLiteRTLMModule? = null

        @Kroll.onAppCreate
        @JvmStatic
        fun onAppCreate(app: TiApplication) {
            Log.d(LCAT, "onAppCreate called")
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private var downloader: LiteRTLMModelDownloaderProxy? = null

    // MARK: - Factory Methods

    @Kroll.method
    fun createDownloader(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMModelDownloaderProxy()
        proxy.handleCreationDict(KrollDict(params))
        val modelsDir = params["modelsDirectory"] as? String
        proxy.initDownloader(modelsDir)
        downloader = proxy
        return proxy
    }

    @Kroll.method
    fun createEngineConfigProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMEngineConfiguration()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createEngineWithConfig(args: Any) {
        val proxy = extractProxy<LiteRTLMEngineConfiguration>(args) ?: return
        val engineProxy = LiteRTLMEngineProxy()
        engineProxy.setConfigProxy(proxy)
        moduleRef = this

        backgroundExecutor.execute {
            try {
                engineProxy.loadEngine(this)
                mainHandler.post {
                    fireEvent("enginecreated", hashMapOf("engine" to engineProxy))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    fireEvent("engineerror", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }
    }

    @Kroll.method
    fun createConversationConfigProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMConversationConfiguration()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createSessionConfigProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMSessionConfiguration()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createSamplerConfigProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMSamplerConfiguration()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createToolProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMTool()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createContentProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMContent()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createMessageProxy(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMMessage()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun createModelInfo(args: Any): KrollProxy? {
        val params = args as? HashMap<String, Any> ?: return null
        val proxy = LiteRTLMModelInfo()
        proxy.handleCreationDict(KrollDict(params))
        return proxy
    }

    @Kroll.method
    fun getVersion(): String {
        return "1.0.0"
    }

    @Kroll.method
    fun closeConversation(args: Any) {
        val proxy = extractProxy<LiteRTLMConversationProxy>(args) ?: return
        proxy.closeConversation()
    }

    @Kroll.method
    fun unloadEngine(args: Any) {
        val proxy = extractProxy<LiteRTLMEngineProxy>(args) ?: return
        proxy.unloadEngine()
    }

    fun getDownloader(): LiteRTLMModelDownloaderProxy? = downloader

    @Suppress("UNCHECKED_CAST")
    private inline fun <reified T : KrollProxy> extractProxy(args: Any): T? {
        return when (args) {
            is T -> args
            is ArrayList<*> -> args.firstOrNull() as? T
            else -> null
        }
    }
}