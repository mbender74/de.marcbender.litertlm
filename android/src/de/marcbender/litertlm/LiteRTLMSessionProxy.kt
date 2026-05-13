package de.marcbender.litertlm

import com.google.ai.edge.litertlm.*
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMSessionProxy : KrollProxy() {

    companion object {
        private const val LCAT = "LiteRTLMSessionProxy"
    }

    private var session: Session? = null
    private var engineProxy: LiteRTLMEngineProxy? = null

    @Kroll.getProperty
    fun getIsActive(): Boolean = session?.isAlive == true

    fun setSession(session: Session, engineProxy: LiteRTLMEngineProxy) {
        this.session = session
        this.engineProxy = engineProxy
    }

    @Kroll.method
    fun generate(args: Any): String? {
        val prompt = args as? String ?: return null
        val sess = session ?: run {
            Log.e(LCAT, "No active session")
            return null
        }
        if (!sess.isAlive) {
            Log.e(LCAT, "Session is not alive")
            return null
        }

        return try {
            val inputData = listOf(InputData.Text(prompt))
            sess.generateContent(inputData)
        } catch (e: Exception) {
            Log.e(LCAT, "Error generating content: ${e.message}")
            fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
            null
        }
    }

    @Kroll.method
    fun generateStream(args: Any) {
        val prompt = args as? String ?: run {
            fireEvent("error", hashMapOf("message" to "Invalid prompt"))
            return
        }
        val sess = session ?: run {
            fireEvent("error", hashMapOf("message" to "No active session"))
            return
        }
        if (!sess.isAlive) {
            fireEvent("error", hashMapOf("message" to "Session is not alive"))
            return
        }

        Thread {
            try {
                val inputData = listOf(InputData.Text(prompt))
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

                sess.generateContentStream(inputData, object : ResponseCallback {
                    override fun onNext(response: String) {
                        mainHandler.post {
                            fireEvent("tokencode", hashMapOf("token" to response))
                        }
                    }

                    override fun onDone() {
                        mainHandler.post {
                            fireEvent("end", hashMapOf<String, Any>())
                        }
                    }

                    override fun onError(throwable: Throwable) {
                        mainHandler.post {
                            fireEvent("error", hashMapOf("message" to (throwable.message ?: "Unknown error")))
                        }
                    }
                })
            } catch (e: Exception) {
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                mainHandler.post {
                    fireEvent("error", hashMapOf("message" to (e.message ?: "Unknown error")))
                }
            }
        }.start()
    }

    @Kroll.method
    fun close() {
        try {
            session?.close()
        } catch (e: Exception) {
            Log.e(LCAT, "Error closing session: ${e.message}")
        }
        session = null
    }
}