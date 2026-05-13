package de.marcbender.litertlm

import android.os.Handler
import android.os.Looper
import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log
import org.appcelerator.titanium.TiApplication
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMModelDownloaderProxy : KrollProxy() {

    companion object {
        private const val LCAT = "LiteRTLMModelDownloader"
    }

    private var modelsDirectory: String = ""
    private var isDownloading = AtomicBoolean(false)
    private var isCancelled = AtomicBoolean(false)
    private var currentConnection: HttpURLConnection? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Kroll.getProperty
    fun getModelsDirectory(): String = modelsDirectory

    @Kroll.setProperty
    fun setModelsDirectory(value: String) { modelsDirectory = resolveTiPath(value) }

    fun initDownloader(modelsDir: String?) {
        modelsDirectory = modelsDir?.let { resolveTiPath(it) } ?: let {
            val app = TiApplication.getInstance()
            File(app.filesDir, "models").absolutePath
        }
        File(modelsDirectory).mkdirs()
    }

    private fun resolveTiPath(path: String): String {
        return when {
            path.startsWith("appdata-private://") -> {
                val app = TiApplication.getInstance()
                File(app.filesDir, path.substringAfter("appdata-private://")).absolutePath
            }
            path.startsWith("appdata://") -> {
                val app = TiApplication.getInstance()
                File(app.filesDir, path.substringAfter("appdata://")).absolutePath
            }
            else -> path
        }
    }

    @Kroll.method
    fun download(args: Any) {
        val modelInfo = args as? LiteRTLMModelInfo
        if (modelInfo != null) {
            downloadFromUrl(modelInfo.url, modelInfo.fileName, modelInfo.expectedSize)
            return
        }

        if (args is HashMap<*, *>) {
            @Suppress("UNCHECKED_CAST")
            val map = args as HashMap<String, Any>
            downloadFromUrl(
                map["url"] as? String ?: "",
                map["fileName"] as? String ?: "",
                (map["expectedSize"] as? Number)?.toLong() ?: 0L
            )
            return
        }

        fireEvent("downloaderror", hashMapOf("message" to "Invalid model info"))
    }

    @Kroll.method
    fun downloadFromUrl(url: String, fileName: String?, expectedSize: Long) {
        if (isDownloading.getAndSet(true)) {
            fireEvent("downloaderror", hashMapOf("message" to "Download already in progress"))
            return
        }

        isCancelled.set(false)

        Thread {
            try {
                val downloadUrl = URL(url)
                val connection = downloadUrl.openConnection() as HttpURLConnection
                connection.connectTimeout = 30000
                connection.readTimeout = 30000
                currentConnection = connection

                connection.connect()

                val responseCode = connection.responseCode
                if (responseCode != HttpURLConnection.HTTP_OK) {
                    mainHandler.post {
                        isDownloading.set(false)
                        fireEvent("downloaderror", hashMapOf("message" to "HTTP error: $responseCode"))
                    }
                    return@Thread
                }

                val contentLength = connection.contentLengthLong
                val actualFileName = fileName ?: url.substringAfterLast("/")
                val targetFile = File(modelsDirectory, actualFileName)
                val tempFile = File(modelsDirectory, "$actualFileName.download")

                if (targetFile.exists() && targetFile.length() == contentLength && contentLength > 0) {
                    mainHandler.post {
                        isDownloading.set(false)
                        fireEvent("downloadcomplete", hashMapOf("fileName" to actualFileName))
                    }
                    return@Thread
                }

                var totalDownloaded = 0L
                var lastProgressTime = 0L

                connection.inputStream.buffered().use { input ->
                    FileOutputStream(tempFile).use { output ->
                        val buffer = ByteArray(8192)
                        var bytesRead: Int

                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            if (isCancelled.get()) {
                                tempFile.delete()
                                mainHandler.post {
                                    isDownloading.set(false)
                                    fireEvent("downloaderror", hashMapOf("message" to "Download cancelled"))
                                }
                                return@Thread
                            }

                            output.write(buffer, 0, bytesRead)
                            totalDownloaded += bytesRead

                            val now = System.currentTimeMillis()
                            if (now - lastProgressTime > 500) {
                                lastProgressTime = now
                                val progress = if (contentLength > 0) {
                                    totalDownloaded.toDouble() / contentLength.toDouble()
                                } else 0.0

                                mainHandler.post {
                                    fireEvent("downloadprogress", hashMapOf(
                                        "progress" to progress,
                                        "bytesDownloaded" to totalDownloaded,
                                        "totalBytes" to contentLength
                                    ))
                                }
                            }
                        }
                    }
                }

                if (targetFile.exists()) targetFile.delete()
                tempFile.renameTo(targetFile)

                mainHandler.post {
                    isDownloading.set(false)
                    fireEvent("downloadcomplete", hashMapOf("fileName" to actualFileName))
                }

            } catch (e: Exception) {
                Log.e(LCAT, "Download error: ${e.message}", e)
                mainHandler.post {
                    isDownloading.set(false)
                    fireEvent("downloaderror", hashMapOf("message" to (e.message ?: "Download failed")))
                }
            } finally {
                currentConnection = null
            }
        }.start()
    }

    @Kroll.method
    fun pause() {
        try { currentConnection?.disconnect() } catch (_: Exception) {}
    }

    @Kroll.method
    fun cancel() {
        isCancelled.set(true)
        try { currentConnection?.disconnect() } catch (_: Exception) {}
    }

    @Kroll.method
    fun isDownloaded(args: Any): Boolean {
        val fileName = extractFileName(args) ?: return false
        return File(modelsDirectory, fileName).exists()
    }

    @Kroll.method
    fun modelPath(args: Any): String? {
        val fileName = extractFileName(args) ?: return null
        val file = File(modelsDirectory, fileName)
        return if (file.exists()) file.absolutePath else null
    }

    @Kroll.method
    fun deleteModel(args: Any) {
        val fileName = extractFileName(args) ?: return
        val file = File(modelsDirectory, fileName)
        if (file.exists()) file.delete()
    }

    private fun extractFileName(args: Any): String? {
        val proxy = args as? LiteRTLMModelInfo
        if (proxy != null) return proxy.fileName

        if (args is HashMap<*, *>) {
            @Suppress("UNCHECKED_CAST")
            return (args as HashMap<String, Any>)["fileName"] as? String
        }
        return null
    }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            val dir = it.getString("modelsDirectory")
            if (dir != null && dir.isNotEmpty() && dir != "undefined") {
                initDownloader(dir)
            } else {
                initDownloader(null)
            }
        }
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