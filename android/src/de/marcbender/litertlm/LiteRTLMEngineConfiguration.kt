package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMEngineConfiguration : KrollProxy() {

    internal var modelPath: String = ""
    internal var backend: String = "CPU"
    internal var maxTokens: Int = -1
    internal var cacheDir: String? = null
    internal var benchmarkEnabled: Boolean = false
    internal var logLevel: String = "warning"
    internal var visionBackend: String? = null
    internal var audioBackend: String? = null

    @Kroll.getProperty fun getModelPath(): String = modelPath
    @Kroll.setProperty fun setModelPath(value: String) { modelPath = value }
    @Kroll.getProperty fun getBackend(): String = backend
    @Kroll.setProperty fun setBackend(value: String) { backend = value }
    @Kroll.getProperty fun getMaxTokens(): Int = maxTokens
    @Kroll.setProperty fun setMaxTokens(value: Int) { maxTokens = value }
    @Kroll.getProperty fun getCacheDir(): String? = cacheDir
    @Kroll.setProperty fun setCacheDir(value: String?) { cacheDir = value }
    @Kroll.getProperty fun getBenchmarkEnabled(): Boolean = benchmarkEnabled
    @Kroll.setProperty fun setBenchmarkEnabled(value: Boolean) { benchmarkEnabled = value }
    @Kroll.getProperty fun getLogLevel(): String = logLevel
    @Kroll.setProperty fun setLogLevel(value: String) { logLevel = value }
    @Kroll.getProperty fun getVisionBackend(): String? = visionBackend
    @Kroll.setProperty fun setVisionBackend(value: String?) { visionBackend = value }
    @Kroll.getProperty fun getAudioBackend(): String? = audioBackend
    @Kroll.setProperty fun setAudioBackend(value: String?) { audioBackend = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            modelPath = it.getString("modelPath") ?: modelPath
            backend = it.getString("backend") ?: backend
            maxTokens = (it["maxTokens"] as? Number)?.toInt() ?: maxTokens
            cacheDir = it.getString("cacheDir")
            benchmarkEnabled = (it["benchmarkEnabled"] as? Boolean) ?: benchmarkEnabled
            logLevel = it.getString("logLevel") ?: logLevel
            visionBackend = it.getString("visionBackend")
            audioBackend = it.getString("audioBackend")
        }
    }
}