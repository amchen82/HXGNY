package com.hxgny.app.data

import android.content.Context
import com.hxgny.app.model.ClassItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer

class ScheduleStorage(
    context: Context,
    private val json: Json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
) {
    private val prefs = context.getSharedPreferences("hxgny.schedule", Context.MODE_PRIVATE)
    private val key = "saved_classes"

    @OptIn(ExperimentalSerializationApi::class)
    suspend fun load(): List<ClassItem> = withContext(Dispatchers.IO) {
        val stored = prefs.getString(key, null) ?: return@withContext emptyList()
        runCatching {
            val serializer = ListSerializer(serializer<ClassItem>())
            json.decodeFromString(serializer, stored)
        }.getOrElse { emptyList() }
    }

    @OptIn(ExperimentalSerializationApi::class)
    suspend fun save(items: List<ClassItem>) = withContext(Dispatchers.IO) {
        val unique = items.distinctBy { it.id }
        val serializer = ListSerializer(serializer<ClassItem>())
        val encoded = json.encodeToString(serializer, unique)
        prefs.edit().putString(key, encoded).apply()
    }
}
