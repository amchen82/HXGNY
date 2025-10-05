package com.hxgny.app.data

import android.content.Context
import com.hxgny.app.model.ClassItem
import com.hxgny.app.model.NoticeItem
import com.hxgny.app.model.OneColumnItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale
import java.util.UUID

class HxgnyRepository(
    private val context: Context,
    private val json: Json = Json { encodeDefaults = true; ignoreUnknownKeys = true },
    private val client: OpenSheetClient = OpenSheetClient(),
    private val cache: CacheStorage = CacheStorage(context),
    private val scheduleStorage: ScheduleStorage = ScheduleStorage(context)
) {
    private val classCacheName = "classes.json"

    suspend fun loadClasses(): List<ClassItem> {
        return cache.loadList<ClassItem>(classCacheName)
            ?: cache.loadAssetList<ClassItem>("classes.json")
            ?: emptyList()
    }

    suspend fun refreshClasses(): Boolean {
        val url = SheetConfig.CLASSES_SHEET_URL
        val rows = runCatching { client.fetchRows(url) }.getOrDefault(emptyList())
        val mapped = rows.mapNotNull { mapRowToClass(it) }
        if (mapped.isEmpty()) return false
        cache.saveList(classCacheName, mapped)
        return true
    }

    fun lastUpdatedForClasses(): Long? = cache.lastUpdated(classCacheName)

    suspend fun loadSavedClasses(): List<ClassItem> = scheduleStorage.load()

    suspend fun saveSchedule(items: List<ClassItem>) = scheduleStorage.save(items)

    suspend fun loadOneColumn(slug: OneColumnSlug): List<OneColumnItem> {
        val cacheName = slug.cacheName()
        return cache.loadList<OneColumnItem>(cacheName)
            ?: slug.assetName?.let { cache.loadAssetList<OneColumnItem>(it) }
            ?: emptyList()
    }

    suspend fun refreshOneColumn(slug: OneColumnSlug): Boolean {
        val cacheName = slug.cacheName()
        val url = slug.sheetUrl ?: return false
        val rows = runCatching { client.fetchRows(url) }.getOrDefault(emptyList())
        val mapped = rows.mapNotNull { mapRowToOneColumn(it, slug) }
        if (mapped.isEmpty()) return false
        cache.saveList(cacheName, mapped)
        return true
    }

    fun lastUpdatedForOneColumn(slug: OneColumnSlug): Long? = cache.lastUpdated(slug.cacheName())

    suspend fun loadNotices(): List<NoticeItem> {
        return cache.loadList<NoticeItem>("notices.json") ?: emptyList()
    }

    suspend fun refreshNotices(): Boolean {
        val url = OneColumnSlug.WeeklyNews.sheetUrl ?: return false
        val rows = runCatching { client.fetchRows(url) }.getOrDefault(emptyList())
        val mapped = rows.mapNotNull { mapRowToNotice(it) }.sortedByDescending { it.dateMillis }
        if (mapped.isEmpty()) return false
        cache.saveList("notices.json", mapped)
        return true
    }

    fun lastUpdatedForNotices(): Long? = cache.lastUpdated("notices.json")

    private fun mapRowToClass(row: Map<String, String>): ClassItem? {
        val normalized = row.normalizeKeys()
        val title = normalized.valueFor("title", "name") ?: return null
        val teacher = normalized.valueFor("teacher", "instructor") ?: ""
        val day = normalized.valueFor("day") ?: ""
        val time = normalized.valueFor("time") ?: ""
        val grade = normalized.valueFor("grade", "age") ?: ""
        val room = normalized.valueFor("room", "location") ?: ""
        val category = normalized.valueFor("category", "type") ?: ""
        val chineseTeacher = normalized.valueFor("chineseTeacher", "chinese teacher", "中文老师")
        val building = normalized.valueFor("buildingHint", "building", "hint")
        val id = normalized.valueFor("id") ?: UUID.randomUUID().toString()
        return ClassItem(
            id = id,
            title = title.ifBlank { return null },
            teacher = teacher,
            chineseTeacher = chineseTeacher,
            day = day,
            time = time,
            grade = grade,
            room = room,
            buildingHint = building,
            category = category
        )
    }

    private fun mapRowToOneColumn(row: Map<String, String>, slug: OneColumnSlug): OneColumnItem? {
        val normalized = row.normalizeKeys()
        val desiredKey = slug.columnName?.lowercase(Locale.US)
        val text = desiredKey?.let { normalized[it] } ?: normalized.values.firstOrNull { it.isNotBlank() }
        val cleaned = text?.trim().orEmpty()
        if (cleaned.isEmpty()) return null
        return OneColumnItem(text = cleaned)
    }

    private fun mapRowToNotice(row: Map<String, String>): NoticeItem? {
        val normalized = row.normalizeKeys()
        val message = normalized.values.firstOrNull { it.isNotBlank() && it != normalized["date"] } ?: return null
        val dateRaw = normalized.valueFor("date") ?: ""
        val millis = parseDateMillis(dateRaw) ?: System.currentTimeMillis()
        val id = normalized.valueFor("id") ?: UUID.randomUUID().toString()
        return NoticeItem(id = id, dateMillis = millis, message = message.trim())
    }

    private fun Map<String, String>.normalizeKeys(): Map<String, String> = entries.associate { (key, value) ->
        key.trim().lowercase(Locale.US) to value.trim()
    }

    private fun Map<String, String>.valueFor(vararg keys: String): String? {
        val normalized = this
        keys.forEach { key ->
            normalized[key.lowercase(Locale.US)]?.let { return it.trim() }
        }
        return null
    }

    private fun OneColumnSlug.cacheName(): String = "onecol_" + slug + ".json"

    private fun parseDateMillis(raw: String): Long? {
        if (raw.isBlank()) return null
        val trimmed = raw.trim()
        val patterns = listOf("yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "M/d/yy")
        patterns.forEach { pattern ->
            try {
                val formatter = DateTimeFormatter.ofPattern(pattern, Locale.US)
                val date = LocalDate.parse(trimmed, formatter)
                return date.atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
            } catch (ignored: DateTimeParseException) {
                // continue
            }
        }
        return null
    }
}
