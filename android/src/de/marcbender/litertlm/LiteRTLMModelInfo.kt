package de.marcbender.litertlm

import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.annotations.Kroll

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMModelInfo : KrollProxy() {

    internal var name: String = ""
    internal var displayName: String = ""
    internal var url: String = ""
    internal var expectedSize: Long = 0L
    internal var fileName: String = ""

    @Kroll.getProperty fun getName(): String = name
    @Kroll.setProperty fun setName(value: String) { name = value }
    @Kroll.getProperty fun getDisplayName(): String = displayName
    @Kroll.setProperty fun setDisplayName(value: String) { displayName = value }
    @Kroll.getProperty fun getUrl(): String = url
    @Kroll.setProperty fun setUrl(value: String) { url = value }
    @Kroll.getProperty fun getExpectedSize(): Long = expectedSize
    @Kroll.setProperty fun setExpectedSize(value: Long) { expectedSize = value }
    @Kroll.getProperty fun getFileName(): String = fileName
    @Kroll.setProperty fun setFileName(value: String) { fileName = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            name = it.getString("name") ?: name
            displayName = it.getString("displayName") ?: displayName
            url = it.getString("url") ?: url
            expectedSize = (it["expectedSize"] as? Number)?.toLong() ?: expectedSize
            fileName = it.getString("fileName") ?: fileName
        }
    }
}