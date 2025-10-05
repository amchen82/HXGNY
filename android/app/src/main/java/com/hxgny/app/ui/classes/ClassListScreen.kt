package com.hxgny.app.ui.classes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hxgny.app.model.ClassItem
import java.text.DateFormat
import java.util.Date
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClassListScreen(
    state: ClassesUiState,
    onQueryChanged: (String) -> Unit,
    onCategoryChanged: (String) -> Unit,
    onToggleOnSite: (Boolean) -> Unit,
    onToggleSaved: (ClassItem) -> Unit,
    onRefresh: () -> Unit,
    onNavigateUp: () -> Unit,
    onOpenDetails: (ClassItem) -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Classes") },
                navigationIcon = {
                    IconButton(onClick = onNavigateUp) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            FilterBar(
                state = state,
                onQueryChanged = onQueryChanged,
                onCategoryChanged = onCategoryChanged,
                onToggleOnSite = onToggleOnSite
            )
            if (state.isLoading && state.filteredClasses.isEmpty()) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 16.dp)
                ) {
                    items(state.filteredClasses, key = { it.id }) { item ->
                        ClassRow(
                            item = item,
                            isSaved = state.saved.any { it.id == item.id },
                            onToggleSaved = { onToggleSaved(item) },
                            onClick = { onOpenDetails(item) }
                        )
                        Divider()
                    }
                    item {
                        state.lastUpdated?.let {
                            Text(
                                text = "Last updated: " + formatTimestamp(it),
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 12.dp),
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterBar(
    state: ClassesUiState,
    onQueryChanged: (String) -> Unit,
    onCategoryChanged: (String) -> Unit,
    onToggleOnSite: (Boolean) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        OutlinedTextField(
            value = state.query,
            onValueChange = onQueryChanged,
            label = { Text("Search class, teacher, room…") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            val categories = remember(state.categories) { listOf("") + state.categories }
            AssistChip(
                onClick = {
                    val currentIndex = categories.indexOf(state.selectedCategory).takeIf { it >= 0 } ?: 0
                    val nextIndex = (currentIndex + 1) % categories.size
                    onCategoryChanged(categories[nextIndex])
                },
                label = {
                    val label = if (state.selectedCategory.isBlank()) "All Categories" else state.selectedCategory
                    Text(label)
                },
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    labelColor = MaterialTheme.colorScheme.onSurface
                )
            )
            AssistChip(
                onClick = { onToggleOnSite(!state.onSiteOnly) },
                label = {
                    Text(if (state.onSiteOnly) "On-site only" else "All locations")
                },
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = if (state.onSiteOnly) MaterialTheme.colorScheme.primary.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
                    labelColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    }
}

@Composable
private fun ClassRow(
    item: ClassItem,
    isSaved: Boolean,
    onToggleSaved: () -> Unit,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 1.dp,
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(item.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(item.grade, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.secondary)
                }
                IconButton(onClick = onToggleSaved) {
                    Icon(
                        imageVector = if (isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "Toggle saved"
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(item.day + " • " + item.time, style = MaterialTheme.typography.bodySmall)
            Text(
                text = "Room " + item.room + (item.buildingHint?.let { " • " + it } ?: ""),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (item.chineseTeacher != null && item.chineseTeacher.isNotBlank()) {
                Text(
                    text = "中文老师: " + item.chineseTeacher,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

private fun formatTimestamp(millis: Long): String {
    val formatter = DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT)
    return formatter.format(Date(millis))
}


