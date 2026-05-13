package de.marcbender.litertlm

import com.google.ai.edge.litertlm.*
import org.appcelerator.kroll.KrollDict
import org.appcelerator.kroll.KrollProxy
import org.appcelerator.kroll.KrollFunction
import org.appcelerator.kroll.KrollObject
import org.appcelerator.kroll.annotations.Kroll
import org.appcelerator.kroll.common.Log
import com.google.gson.JsonObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@Kroll.proxy(creatableInModule = TitaniumLiteRTLMModule::class)
class LiteRTLMTool : KrollProxy() {

    companion object {
        private const val LCAT = "LiteRTLMTool"
    }

    internal var name: String = ""
    internal var description: String = ""
    internal var parameters: List<Map<String, Any?>> = emptyList()
    internal var executeCallback: KrollFunction? = null

    @Kroll.getProperty
    fun getName(): String = name

    @Kroll.setProperty
    fun setName(value: String) { name = value }

    @Kroll.getProperty
    fun getDescription(): String = description

    @Kroll.setProperty
    fun setDescription(value: String) { description = value }

    @Kroll.getProperty
    fun getParameters(): Any = parameters

    @Kroll.setProperty
    fun setParameters(value: Any?) {
        @Suppress("UNCHECKED_CAST")
        parameters = when (value) {
            is ArrayList<*> -> value.filterIsInstance<Map<String, Any?>>()
            else -> emptyList()
        }
    }

    @Kroll.getProperty
    fun getExecuteCallback(): KrollFunction? = executeCallback

    @Kroll.setProperty
    fun setExecuteCallback(value: KrollFunction?) { executeCallback = value }

    override fun handleCreationDict(options: KrollDict?) {
        super.handleCreationDict(options)
        options?.let {
            name = it.getString("name") ?: name
            description = it.getString("description") ?: description

            val paramsObj = it["parameters"]
            if (paramsObj is ArrayList<*>) {
                @Suppress("UNCHECKED_CAST")
                parameters = paramsObj.filterIsInstance<Map<String, Any?>>()
            }
        }
    }

    fun toOpenApiTool(): OpenApiTool {
        val toolProxy = this
        return object : OpenApiTool {
            override fun getToolDescriptionJsonString(): String {
                val root = JsonObject()
                root.addProperty("name", toolProxy.name)
                root.addProperty("description", toolProxy.description)

                if (toolProxy.parameters.isNotEmpty()) {
                    val properties = JsonObject()
                    val required = com.google.gson.JsonArray()

                    for (param in toolProxy.parameters) {
                        val paramName = param["name"] as? String ?: continue
                        val paramType = param["type"] as? String ?: "string"
                        val paramDesc = param["description"] as? String ?: ""
                        val paramRequired = param["required"] as? Boolean ?: false

                        val propObj = JsonObject()
                        propObj.addProperty("type", paramType)
                        if (paramDesc.isNotEmpty()) {
                            propObj.addProperty("description", paramDesc)
                        }
                        properties.add(paramName, propObj)

                        if (paramRequired) {
                            required.add(paramName)
                        }
                    }

                    val paramsObj = JsonObject()
                    paramsObj.addProperty("type", "object")
                    paramsObj.add("properties", properties)
                    if (required.size() > 0) {
                        paramsObj.add("required", required)
                    }
                    root.add("parameters", paramsObj)
                }

                return root.toString()
            }

            override fun execute(paramsJsonString: String): String {
                val callback = toolProxy.executeCallback ?: return "{}"

                val latch = CountDownLatch(1)
                val resultHolder = arrayOfNulls<String>(1)

                try {
                    val krollObject = toolProxy.krollObject
                    val args = arrayOf<Any>(paramsJsonString)

                    // Try calling on the Kroll thread
                    val activity = org.appcelerator.titanium.TiApplication.getInstance().currentActivity
                    activity?.runOnUiThread {
                        try {
                            val jsResult = callback.call(krollObject, args)
                            resultHolder[0] = when (jsResult) {
                                is String -> jsResult
                                is HashMap<*, *> -> {
                                    val jsonObj = JsonObject()
                                    @Suppress("UNCHECKED_CAST")
                                    for ((key, value) in jsResult as Map<String, Any?>) {
                                        when (value) {
                                            is String -> jsonObj.addProperty(key, value)
                                            is Number -> jsonObj.addProperty(key, value)
                                            is Boolean -> jsonObj.addProperty(key, value)
                                            null -> jsonObj.add(key, com.google.gson.JsonNull.INSTANCE)
                                            else -> jsonObj.addProperty(key, value.toString())
                                        }
                                    }
                                    jsonObj.toString()
                                }
                                else -> jsResult?.toString() ?: "{}"
                            }
                        } catch (e: Exception) {
                            Log.e(LCAT, "Error executing tool callback: ${e.message}")
                            resultHolder[0] = "{\"error\": \"${e.message}\"}"
                        } finally {
                            latch.countDown()
                        }
                    } ?: run {
                        resultHolder[0] = "{}"
                        latch.countDown()
                    }
                } catch (e: Exception) {
                    Log.e(LCAT, "Error calling tool callback: ${e.message}")
                    resultHolder[0] = "{\"error\": \"${e.message}\"}"
                    latch.countDown()
                }

                latch.await(30, TimeUnit.SECONDS)
                return resultHolder[0] ?: "{}"
            }
        }
    }
}