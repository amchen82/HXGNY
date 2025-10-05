package com.hxgny.app.ui.classes

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowBack
//import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.hxgny.app.model.ClassItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClassDetailScreen(item: ClassItem, onNavigateUp: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Details") },
                navigationIcon = {
                    androidx.compose.material3.IconButton(onClick = onNavigateUp) {
                        androidx.compose.material3.Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .padding(16.dp)
        ) {
            InfoRow(label = "Title", value = item.title)
            InfoRow(label = "Teacher", value = item.teacher)
            item.chineseTeacher?.takeIf { it.isNotBlank() }?.let {
                InfoRow(label = "中文老师", value = it)
            }
            InfoRow(label = "Grade", value = item.grade)
            InfoRow(label = "Category", value = item.category)
            Divider(modifier = Modifier.padding(vertical = 12.dp))
            InfoRow(label = "Day", value = item.day)
            InfoRow(label = "Time", value = item.time)
            InfoRow(label = "Room", value = item.room)
            InfoRow(label = "Building", value = item.buildingHint ?: "—")
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Column(modifier = Modifier
        .fillMaxWidth()
        .padding(vertical = 6.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        Text(value, style = MaterialTheme.typography.bodyLarge)
    }
}
