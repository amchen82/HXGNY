package com.hxgny.app.ui.onecolumn

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.AnnotatedString.Builder
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import java.text.DateFormat
import java.util.Date
import java.util.regex.Pattern
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun OneColumnScreen(
    title: String,
    state: OneColumnUiState,
    onRefresh: () -> Unit,
    onNavigateUp: () -> Unit
) {
    val context = LocalContext.current
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onNavigateUp) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Outlined.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp)
        ) {
            if (state.items.isEmpty()) {
                item {
                    Text("No content yet. Pull to refresh or check back later.", style = MaterialTheme.typography.bodyMedium)
                }
            } else {
                items(state.items) { item ->
                    val annotated = remember(item.text) { linkify(item.text) }
                    androidx.compose.foundation.text.ClickableText(
                        text = annotated,
                        style = MaterialTheme.typography.bodyMedium,
                        onClick = { offset ->
                            annotated.getStringAnnotations("URL", offset, offset).firstOrNull()?.let { link ->
                                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(link.item)))
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp)
                    )
                }
            }
            state.lastUpdated?.let { timestamp ->
                item {
                    Text(
                        text = "Last updated: " + formatTimestamp(timestamp),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                }
            }
        }
    }
}

private fun linkify(text: String): AnnotatedString {
    val pattern = Pattern.compile("""https?://\S+""")
    val matcher = pattern.matcher(text)
    val builder = Builder()
    var lastIndex = 0
    while (matcher.find()) {
        val start = matcher.start()
        val end = matcher.end()
        if (start > lastIndex) {
            builder.append(text.substring(lastIndex, start))
        }
        val url = text.substring(start, end)
        builder.pushStringAnnotation(tag = "URL", annotation = url)
        builder.withStyle(SpanStyle(color = Color(0xFF1D4ED8), textDecoration = TextDecoration.Underline)) {
            append(url)
        }
        builder.pop()
        lastIndex = end
    }
    if (lastIndex < text.length) {
        builder.append(text.substring(lastIndex))
    }
    return builder.toAnnotatedString()
}

private fun formatTimestamp(millis: Long): String {
    val formatter = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
    return formatter.format(Date(millis))
}
