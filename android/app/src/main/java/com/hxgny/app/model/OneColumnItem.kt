package com.hxgny.app.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class OneColumnItem(
    val id: String = UUID.randomUUID().toString(),
    val text: String
)
