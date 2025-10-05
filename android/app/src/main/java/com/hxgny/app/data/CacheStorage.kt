package com.hxgny.app.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer
import java.io.File
import java.nio.charset.StandardCharsets

class CacheStorage(
    val context: Context,
     val json: Json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
) {
     val prefs by lazy {
        context.getSharedPreferences("hxgny.cache", Context.MODE_PRIVATE)
    }

    fun cacheFile(name: String): File = File(context.filesDir, name)

    @OptIn(ExperimentalSerializationApi::class)
    suspend inline fun <reified T> loadList(name: String): List<T>? = withContext(Dispatchers.IO) {
        val file = cacheFile(name)
        if (!file.exists()) return@withContext null
        runCatching {
            val serializer = ListSerializer(serializer<T>())
            json.decodeFromString(serializer, file.readText(StandardCharsets.UTF_8))
        }.getOrNull()
    }

    @OptIn(ExperimentalSerializationApi::class)
    suspend inline fun <reified T> loadAssetList(assetName: String): List<T>? = withContext(Dispatchers.IO) {
        runCatching {
            context.assets.open(assetName).use { input ->
                val serializer = ListSerializer(serializer<T>())
                val text = input.reader(StandardCharsets.UTF_8).readText()
                json.decodeFromString(serializer, text)
            }
        }.getOrNull()
    }

    @OptIn(ExperimentalSerializationApi::class)
    suspend inline fun <reified T> saveList(name: String, data: List<T>) = withContext(Dispatchers.IO) {
        val file = cacheFile(name)
        val serializer = ListSerializer(serializer<T>())
        file.writeText(json.encodeToString(serializer, data), StandardCharsets.UTF_8)
        prefs.edit().putLong(name.toLastUpdatedKey(), System.currentTimeMillis()).apply()
    }

    fun lastUpdated(name: String): Long? = prefs.getLong(name.toLastUpdatedKey(), 0L).takeIf { it > 0 }

     fun String.toLastUpdatedKey(): String = "last_updated_" + this.replace('.', '_')
}
