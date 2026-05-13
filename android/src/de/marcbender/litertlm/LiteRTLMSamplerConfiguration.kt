package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMSamplerConfiguration : KrollProxy() {

    internal var temperature: Double = 0.7
    internal var topK: Int = 40
    internal var topP: Double = 0.95
    internal var seed: Int = 0
    internal var samplerType: String = "topK"

    @Kroll.getProperty fun getTemperature(): Double = temperature
    @Kroll.setProperty fun setTemperature(value: Double) { temperature = value }
    @Kroll.getProperty fun getTopK(): Int = topK
    @Kroll.setProperty fun setTopK(value: Int) { topK = value }
    @Kroll.getProperty fun getTopP(): Double = topP
    @Kroll.setProperty fun setTopP(value: Double) { topP = value }
    @Kroll.getProperty fun getSeed(): Int = seed
    @Kroll.setProperty fun setSeed(value: Int) { seed = value }
    @Kroll.getProperty fun getSamplerType(): String = samplerType
    @Kroll.setProperty fun setSamplerType(value: String) { samplerType = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            temperature = (it["temperature"] as? Number)?.toDouble() ?: temperature
            topK = (it["topK"] as? Number)?.toInt() ?: topK
            topP = (it["topP"] as? Number)?.toDouble() ?: topP
            seed = (it["seed"] as? Number)?.toInt() ?: seed
            samplerType = it.getString("samplerType") ?: samplerType
        }
    }
}