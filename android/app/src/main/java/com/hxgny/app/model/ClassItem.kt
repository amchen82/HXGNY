package com.hxgny.app.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class ClassItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val teacher: String,
    @SerialName("chineseTeacher") val chineseTeacher: String? = null,
    val day: String,
    val time: String,
    val grade: String,
    val room: String,
    val buildingHint: String? = null,
    val category: String
) {
    val minAge: Int?
        get() {
            val normalized = grade.trim().lowercase()
            val ageRegex = Regex("""(\d{1,2})(?=\s*岁)""")
            ageRegex.find(normalized)?.let { match ->
                return match.value.toIntOrNull()
            }
            if ("prek" in normalized || "pre-k" in normalized) return 4
            if (("k" in normalized) && !("1st".lowercase() in normalized)) return 5

            val gradeMap = mapOf(
                "1st" to 6, "2nd" to 7, "3rd" to 8, "4th" to 9,
                "5th" to 10, "6th" to 11, "7th" to 12, "8th" to 13,
                "9th" to 14, "10th" to 15, "11th" to 16, "12th" to 17
            )
            gradeMap.forEach { (keyword, age) ->
                if (normalized.contains(keyword.lowercase())) return age
            }
            if (normalized.contains("& up")) {
                gradeMap.forEach { (keyword, age) ->
                    if (normalized.contains(keyword.lowercase())) return age
                }
            }
            if (normalized.contains("adult")) return 18
            return null
        }

    fun matches(query: String): Boolean {
        if (query.isBlank()) return true
        val q = query.trim().lowercase()
        val age = q.toIntOrNull()
        if (age != null) {
            return minAge == age
        }
        return listOfNotNull(
            title,
            teacher,
            chineseTeacher,
            day,
            time,
            grade,
            room,
            category,
            buildingHint
        )
            .joinToString(" ")
            .lowercase()
            .contains(q)
    }

    fun isOnSite(): Boolean {
        val r = room.lowercase()
        return !("online" in r || "zoom" in r)
    }
}
