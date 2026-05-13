package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMMessage : KrollProxy() {

    internal var role: String = "user"
    internal var contents: List<LiteRTLMContent> = emptyList()

    @Kroll.getProperty fun getRole(): String = role
    @Kroll.setProperty fun setRole(value: String) { role = value }
    @Kroll.getProperty fun getContents(): Any = contents
    @Kroll.setProperty fun setContents(value: Any?) {
        @Suppress("UNCHECKED_CAST")
        val items = when (value) {
            is ArrayList<*> -> value
            is Array<*> -> value.toList()
            else -> null
        }
        contents = items?.mapNotNull { item ->
            when (item) {
                is LiteRTLMContent -> item
                is HashMap<*, *> -> {
                    val content = LiteRTLMContent()
                    content.handleCreationDict(KrollDict(item as HashMap<String, Any>))
                    content
                }
                else -> null
            }
        } ?: emptyList()
    }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            role = it.getString("role") ?: role

            val contentsObj = it["contents"]
            val items = when (contentsObj) {
                is ArrayList<*> -> contentsObj
                is Array<*> -> contentsObj.toList()
                else -> null
            }
            if (items != null) {
                contents = items.mapNotNull { item ->
                    when (item) {
                        is LiteRTLMContent -> item
                        is HashMap<*, *> -> {
                            val content = LiteRTLMContent()
                            content.handleCreationDict(KrollDict(item as HashMap<String, Any>))
                            content
                        }
                        else -> null
                    }
                }
            }
        }
    }
}