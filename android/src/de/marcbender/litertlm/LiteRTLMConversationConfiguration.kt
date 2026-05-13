package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMConversationConfiguration : KrollProxy() {

    internal var maxOutputTokens: Int = 2048
    internal var samplerType: String = "balanced"
    internal var toolExecutionMode: String = "automatic"
    internal var maxImageDimension: Int = 1024
    internal var systemPrompt: String? = null
    internal var tools: List<LiteRTLMTool> = emptyList()

    @Kroll.getProperty fun getMaxOutputTokens(): Int = maxOutputTokens
    @Kroll.setProperty fun setMaxOutputTokens(value: Int) { maxOutputTokens = value }
    @Kroll.getProperty fun getSamplerType(): String = samplerType
    @Kroll.setProperty fun setSamplerType(value: String) { samplerType = value }
    @Kroll.getProperty fun getToolExecutionMode(): String = toolExecutionMode
    @Kroll.setProperty fun setToolExecutionMode(value: String) { toolExecutionMode = value }
    @Kroll.getProperty fun getMaxImageDimension(): Int = maxImageDimension
    @Kroll.setProperty fun setMaxImageDimension(value: Int) { maxImageDimension = value }
    @Kroll.getProperty fun getSystemPrompt(): String? = systemPrompt
    @Kroll.setProperty fun setSystemPrompt(value: String?) { systemPrompt = value }
    @Kroll.getProperty fun getTools(): Any = tools
    @Kroll.setProperty fun setTools(value: Any?) {
        @Suppress("UNCHECKED_CAST")
        tools = when (value) {
            is ArrayList<*> -> value.filterIsInstance<LiteRTLMTool>()
            else -> emptyList()
        }
    }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            maxOutputTokens = (it["maxOutputTokens"] as? Number)?.toInt() ?: maxOutputTokens
            samplerType = it.getString("samplerType") ?: samplerType
            toolExecutionMode = it.getString("toolExecutionMode") ?: toolExecutionMode
            maxImageDimension = (it["maxImageDimension"] as? Number)?.toInt() ?: maxImageDimension
            systemPrompt = it.getString("systemPrompt")

            val toolsArr = it["tools"]
            if (toolsArr is ArrayList<*>) {
                tools = toolsArr.filterIsInstance<LiteRTLMTool>()
            }
        }
    }
}