package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMSessionConfiguration : KrollProxy() {

    internal var maxOutputTokens: Int = 512
    internal var samplerType: String = "balanced"

    @Kroll.getProperty fun getMaxOutputTokens(): Int = maxOutputTokens
    @Kroll.setProperty fun setMaxOutputTokens(value: Int) { maxOutputTokens = value }
    @Kroll.getProperty fun getSamplerType(): String = samplerType
    @Kroll.setProperty fun setSamplerType(value: String) { samplerType = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            maxOutputTokens = (it["maxOutputTokens"] as? Number)?.toInt() ?: maxOutputTokens
            samplerType = it.getString("samplerType") ?: samplerType
        }
    }
}