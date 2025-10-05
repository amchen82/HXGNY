package com.hxgny.app.ui.components

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private const val PLAY_STORE_ID = "com.hxgny.app"

@Composable
fun UpdateButton() {
    val context = LocalContext.current
    TextButton(onClick = {
        val marketUri = Uri.parse("market://details?id=")
        val webUri = Uri.parse("https://play.google.com/store/apps/details?id=")
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, marketUri))
        } catch (_: ActivityNotFoundException) {
            context.startActivity(Intent(Intent.ACTION_VIEW, webUri))
        }
    }) {
        androidx.compose.material3.Text(text = "Install Update")
    }
}
