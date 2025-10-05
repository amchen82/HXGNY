package com.hxgny.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

class OpenSheetClient(
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    suspend fun fetchRows(url: String): List<Map<String, String>> = withContext(Dispatchers.IO) {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15_000
            readTimeout = 15_000
        }
        try {
            val stream = if (connection.responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val body = stream.bufferedReader(StandardCharsets.UTF_8).use(BufferedReader::readText)
            parseRows(body)
        } finally {
            connection.disconnect()
        }
    }

    private fun parseRows(raw: String): List<Map<String, String>> {
        val element: JsonElement = json.parseToJsonElement(raw)
        val rows = element as? JsonArray ?: return emptyList()
        return rows.mapNotNull { row ->
            val obj = row as? JsonObject ?: return@mapNotNull null
            obj.mapValues { (_, value) ->
                when (value) {
                    is JsonPrimitive -> value?.contentOrNull ?: ""
                    JsonNull -> ""
                    else -> value.toString()
                }
            }
        }
    }
}
