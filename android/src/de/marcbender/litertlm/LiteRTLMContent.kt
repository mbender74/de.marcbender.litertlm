package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMContent : KrollProxy() {

    internal var type: String = "text"
    internal var text: String = ""
    internal var imageData: Any? = null
    internal var audioData: Any? = null
    internal var audioFormat: String = "wav"
    internal var maxDimension: Int = 1024

    @Kroll.getProperty fun getType(): String = type
    @Kroll.setProperty fun setType(value: String) { type = value }
    @Kroll.getProperty fun getText(): String = text
    @Kroll.setProperty fun setText(value: String) { text = value }
    @Kroll.getProperty fun getImageData(): Any? = imageData
    @Kroll.setProperty fun setImageData(value: Any?) { imageData = value }
    @Kroll.getProperty fun getAudioData(): Any? = audioData
    @Kroll.setProperty fun setAudioData(value: Any?) { audioData = value }
    @Kroll.getProperty fun getAudioFormat(): String = audioFormat
    @Kroll.setProperty fun setAudioFormat(value: String) { audioFormat = value }
    @Kroll.getProperty fun getMaxDimension(): Int = maxDimension
    @Kroll.setProperty fun setMaxDimension(value: Int) { maxDimension = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            type = it.getString("type") ?: type
            text = it.getString("text") ?: text
            imageData = it["imageData"]
            audioData = it["audioData"]
            audioFormat = it.getString("audioFormat") ?: audioFormat
            maxDimension = (it["maxDimension"] as? Number)?.toInt() ?: maxDimension
        }
    }
}