package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMMessage : KrollProxy() {

    internal var role: String = "user"
    internal var contents: List<LiteRTLMContent> = emptyList()

    @Kroll.getProperty fun getRole(): String = role
    @Kroll.setProperty fun setRole(value: String) { role = value }
    @Kroll.getProperty fun getContents(): Any = contents
    @Kroll.setProperty fun setContents(value: Any?) {
        @Suppress("UNCHECKED_CAST")
        contents = when (value) {
            is ArrayList<*> -> value.filterIsInstance<LiteRTLMContent>()
            else -> emptyList()
        }
    }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            role = it.getString("role") ?: role

            val contentsObj = it["contents"]
            if (contentsObj is ArrayList<*>) {
                contents = contentsObj.filterIsInstance<LiteRTLMContent>()
            }
        }
    }
}