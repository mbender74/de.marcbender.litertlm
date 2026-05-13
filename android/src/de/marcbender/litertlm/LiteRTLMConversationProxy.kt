package de.marcbender.litertlm

import com.google.ai.edge.litertlm.*
import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log
import org.appcelerator.titanium.TiBlob
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMConversationProxy : KrollProxy() {

    companion object {
        private const val LCAT = "LiteRTLMConversationProxy"
    }

    private var conversation: Conversation? = null
    private var engineProxy: LiteRTLMEngineProxy? = null
    private var configProxy: LiteRTLMConversationConfiguration? = null
    private var toolProxies: List<LiteRTLMTool> = emptyList()
    private var active = false

    @Kroll.getProperty
    fun getIsActive(): Boolean = active

    @Kroll.setProperty
    fun setIsActive(value: Boolean) {
        active = value
    }

    fun setConversation(
        conversation: Conversation,
        engineProxy: LiteRTLMEngineProxy,
        configProxy: LiteRTLMConversationConfiguration?,
        toolProxies: List<LiteRTLMTool>
    ) {
        this.conversation = conversation
        this.engineProxy = engineProxy
        this.configProxy = configProxy
        this.toolProxies = toolProxies
        this.active = true
    }

    // MARK: - Send (blocking, returns full response)

    @Kroll.method
    fun send(text: String) {
        val conv = conversation ?: run {
            fireEvent("error", hashMapOf("message" to "No active conversation"))
            return
        }
        active = true

        Thread {
            try {
                val message = conv.sendMessage(text)
                active = false
                val responseText = message.contents.toString()
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                mainHandler.post {
                    fireEvent("message", hashMapOf("role" to "model", "content" to responseText))
                    fireEvent("messagecomplete", hashMapOf("role" to "model", "content" to responseText))
                }
            } catch (e: Exception) {
                active = false
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                mainHandler.post {
                    fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                    fireEvent("messageerror", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }.start()
    }

    // MARK: - Send Stream (async with callbacks)

    @Kroll.method
    fun sendStream(args: Any) {
        Log.d(LCAT, "sendStream called with args type: ${args.javaClass.simpleName}")
        val text = extractText(args)
        Log.d(LCAT, "sendStream extracted text: '$text'")
        if (text == null) {
            fireEvent("error", hashMapOf("message" to "Invalid message"))
            return
        }

        val conv = conversation ?: run {
            fireEvent("error", hashMapOf("message" to "No active conversation"))
            return
        }

        val hasTools = toolProxies.isNotEmpty()
        active = true

        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        mainHandler.post {
            fireEvent("streamstart", hashMapOf<String, Any>())
        }

        Thread {
            try {
                if (hasTools) {
                    // With tools: use blocking sendMessage (handles tool calls internally)
                    val message = conv.sendMessage(text)
                    active = false
                    val responseText = message.contents.toString()
                    mainHandler.post {
                        fireEvent("token", hashMapOf("token" to responseText))
                        fireEvent("streamcomplete", hashMapOf<String, Any>())
                        fireEvent("streamend", hashMapOf<String, Any>())
                        fireEvent("messagecomplete", hashMapOf("role" to "model", "content" to responseText))
                    }
                } else {
                    // Without tools: use async streaming
                    val callback = object : MessageCallback {
                        override fun onMessage(message: Message) {
                            val token = message.contents.toString()
                            mainHandler.post {
                                fireEvent("token", hashMapOf("token" to token))
                            }
                        }

                        override fun onDone() {
                            active = false
                            mainHandler.post {
                                fireEvent("streamcomplete", hashMapOf<String, Any>())
                                fireEvent("streamend", hashMapOf<String, Any>())
                                fireEvent("messagecomplete", hashMapOf<String, Any>())
                            }
                        }

                        override fun onError(throwable: Throwable) {
                            active = false
                            mainHandler.post {
                                fireEvent("streamerror", hashMapOf("message" to (throwable.message ?: "Unknown error")))
                                fireEvent("messageerror", hashMapOf("message" to (throwable.message ?: "Unknown error")))
                            }
                        }
                    }
                    conv.sendMessageAsync(text, callback)
                }
            } catch (e: Exception) {
                active = false
                mainHandler.post {
                    fireEvent("streamerror", hashMapOf("message" to (e.message ?: "Unknown error")))
                    fireEvent("messageerror", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }.start()
    }

    // MARK: - Send Multimodal

    @Kroll.method
    fun sendMultimodal(args: Any) {
        val msgProxy = args as? LiteRTLMMessage ?: run {
            // Try extracting text from args
            val text = args as? String
            if (text != null) {
                send(text)
                return
            }
            fireEvent("error", hashMapOf("message" to "Invalid message"))
            return
        }

        val conv = conversation ?: run {
            fireEvent("error", hashMapOf("message" to "No active conversation"))
            return
        }

        // Build contents from proxy
        val contents = mutableListOf<Content>()
        for (contentProxy in msgProxy.contents) {
            when (contentProxy.type) {
                "text" -> {
                    if (contentProxy.text.isNotEmpty()) {
                        contents.add(Content.Text(contentProxy.text))
                    }
                }
                "image" -> {
                    val bytes = extractBytes(contentProxy.imageData)
                    if (bytes != null) {
                        contents.add(Content.ImageBytes(bytes))
                    }
                }
                "audio" -> {
                    val bytes = extractBytes(contentProxy.audioData)
                    if (bytes != null) {
                        contents.add(Content.AudioBytes(bytes))
                    }
                }
            }
        }

        active = true
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

        Thread {
            try {
                val message = conv.sendMessage(Contents.of(contents))
                active = false
                val responseText = message.contents.toString()
                mainHandler.post {
                    fireEvent("message", hashMapOf("role" to "model", "content" to responseText))
                    fireEvent("messagecomplete", hashMapOf("role" to "model", "content" to responseText))
                }
            } catch (e: Exception) {
                active = false
                mainHandler.post {
                    fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                    fireEvent("messageerror", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }.start()
    }

    // MARK: - Cancel & Close

    @Kroll.method
    fun cancel() = cancelStream()

    @Kroll.method
    fun cancelStream() {
        try {
            conversation?.cancelProcess()
        } catch (e: Exception) {
            Log.e(LCAT, "Error cancelling stream: ${e.message}")
        }
        active = false
        fireEvent("cancelled", hashMapOf<String, Any>())
    }

    @Kroll.method
    fun close() = closeConversation()

    @Kroll.method
    fun closeConversation() {
        try {
            conversation?.close()
        } catch (e: Exception) {
            Log.e(LCAT, "Error closing conversation: ${e.message}")
        }
        conversation = null
        active = false
        fireEvent("close", hashMapOf<String, Any>())
    }

    // MARK: - Helpers

    private fun extractText(args: Any): String? {
        Log.d(LCAT, "extractText: args type=${args.javaClass.simpleName}, value='$args'")
        val unwrapped = when (args) {
            is ArrayList<*> -> {
                Log.d(LCAT, "extractText: unwrapping ArrayList of size ${args.size}")
                args.firstOrNull()
            }
            else -> args
        }
        Log.d(LCAT, "extractText: unwrapped type=${unwrapped?.javaClass?.simpleName}")
        return when (unwrapped) {
            is String -> {
                Log.d(LCAT, "extractText: got String '$unwrapped'")
                unwrapped
            }
            is LiteRTLMMessage -> {
                Log.d(LCAT, "extractText: got LiteRTLMMessage with ${unwrapped.contents.size} contents")
                val result = unwrapped.contents.filterIsInstance<LiteRTLMContent>()
                    .filter { it.type == "text" }
                    .joinToString(" ") { it.text }
                Log.d(LCAT, "extractText: extracted text from message: '$result'")
                result
            }
            else -> {
                Log.e(LCAT, "extractText: unexpected type ${unwrapped?.javaClass?.simpleName}")
                null
            }
        }
    }

    private fun extractBytes(data: Any?): ByteArray? {
        return when (data) {
            is ByteArray -> data
            is TiBlob -> data.bytes
            else -> null
        }
    }
}