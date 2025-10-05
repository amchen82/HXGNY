package com.hxgny.app.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Serializable
data class NoticeItem(
    val id: String,
    val dateMillis: Long,
    val message: String
) {
    val formattedDate: String
        get() {
            val formatter = DateTimeFormatter.ofPattern("MMM d, yyyy")
            return Instant.ofEpochMilli(dateMillis)
                .atZone(ZoneId.systemDefault())
                .format(formatter)
        }
}
