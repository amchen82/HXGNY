package com.hxgny.app.ui.home

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CarRental
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.QuestionAnswer
import androidx.compose.material.icons.outlined.School
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.hxgny.app.R
import com.hxgny.app.data.OneColumnSlug

sealed class HomeAction {
    data object Classes : HomeAction()
    data object Buildings : HomeAction()
    data object Parking : HomeAction()
    data object Calendar : HomeAction()
    data object Schedule : HomeAction()
    data class OneColumn(val slug: OneColumnSlug) : HomeAction()
    data object WeeklyNews : HomeAction()
}

@Composable
fun HomeScreen(
    classesCount: Int,
    savedCount: Int,
    onAction: (HomeAction) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(bottom = 24.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                painter = painterResource(id = R.drawable.launch_logo),
                contentDescription = null,
                modifier = Modifier.height(96.dp),
                contentScale = ContentScale.Fit
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Huaxia Chinese School of Greater New York",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center
            )
            Text(
                text = "200 White Oak Ln, Scarsdale, NY 10583",
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))
            ContactLinks()
        }

        val cards = remember(classesCount, savedCount) {
            listOf(
                HomeCardData(
                    title = "School Intro",
                    subtitle = "学校简介",
                    icon = Icons.Outlined.Info,
//                    tint = MaterialTheme.colorScheme.primary,
                    action = { onAction(HomeAction.OneColumn(OneColumnSlug.SchoolIntro)) }
                ),
                HomeCardData(
                    title = "Classes",
                    subtitle = "${classesCount.coerceAtLeast(0)} courses",
                    icon = Icons.Outlined.School,
                    action = { onAction(HomeAction.Classes) }
                ),
                HomeCardData(
                    title = "Buildings",
                    subtitle = "Campus map",
                    icon = Icons.Outlined.Map,
                    action = { onAction(HomeAction.Buildings) }
                ),
                HomeCardData(
                    title = "Parking",
                    subtitle = "停车地图",
                    icon = Icons.Outlined.CarRental,
                    action = { onAction(HomeAction.Parking) }
                ),
                HomeCardData(
                    title = "Weekly News",
                    subtitle = "校园周报",
                    icon = Icons.Outlined.Notifications,
                    action = { onAction(HomeAction.WeeklyNews) }
                ),
                HomeCardData(
                    title = "School Calendar",
                    subtitle = "校历",
                    icon = Icons.Outlined.CalendarMonth,
                    action = { onAction(HomeAction.Calendar) }
                ),
                HomeCardData(
                    title = "My Schedule",
                    subtitle = "${savedCount.coerceAtLeast(0)} saved",
                    icon = Icons.Outlined.Bookmark,
                    action = { onAction(HomeAction.Schedule) }
                ),
                HomeCardData(
                    title = "Lost & Found",
                    subtitle = "失物招领",
                    icon = Icons.Outlined.QuestionAnswer,
                    action = { onAction(HomeAction.OneColumn(OneColumnSlug.LostFound)) }
                ),
                HomeCardData(
                    title = "Sponsors",
                    subtitle = "赞助",
                    icon = Icons.Outlined.People,
                    action = { onAction(HomeAction.OneColumn(OneColumnSlug.Sponsors)) }
                ),
                HomeCardData(
                    title = "Contact Us",
                    subtitle = "联系我们",
                    icon = Icons.Outlined.Email,
                    action = { onAction(HomeAction.OneColumn(OneColumnSlug.Contact)) }
                ),
                HomeCardData(
                    title = "Join Us",
                    subtitle = "加入我们",
                    icon = Icons.Outlined.PersonAdd,
                    action = { onAction(HomeAction.OneColumn(OneColumnSlug.JoinUs)) }
                )
            )
        }

        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 160.dp),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            items(cards) { card ->
                ElevatedCard(
                    onClick = card.action,
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.elevatedCardColors()
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        AssistChip(
                            onClick = card.action,
                            label = { Text(card.title) },
                            leadingIcon = {
                                Icon(
                                    imageVector = card.icon,
                                    contentDescription = null,
//                                    tint = card.tint ?: MaterialTheme.colorScheme.primary
                                )
                            },
                            colors = AssistChipDefaults.assistChipColors(
                                containerColor = MaterialTheme.colorScheme.surface,
                                labelColor = MaterialTheme.colorScheme.onSurface
                            )
                        )
                        Text(card.subtitle, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}

@Composable
private fun ContactLinks() {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        LinkRow(icon = Icons.Outlined.Home, label = "www.hxgny.org", url = "https://www.hxgny.org")
        Spacer(modifier = Modifier.height(4.dp))
        LinkRow(icon = Icons.Outlined.Email, label = "hxgnyadmin@googlegroups.com", url = "mailto:hxgnyadmin@googlegroups.com")
    }
}

@Composable
private fun LinkRow(icon: ImageVector, label: String, url: String) {
    val context = LocalContext.current
    val annotated = remember(url, label) {
        buildAnnotatedString {
            pushStringAnnotation(tag = "URL", annotation = url)
            withStyle(
                SpanStyle(
//                    color = MaterialTheme.colorScheme.primary,
                    textDecoration = TextDecoration.Underline
                )
            ) {
                append(label)
            }
            pop()
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
        val context = LocalContext.current
        ClickableText(
            text = annotated,
            style = MaterialTheme.typography.bodySmall,
            onClick = { offset ->
                annotated.getStringAnnotations(tag = "URL", start = offset, end = offset)
                    .firstOrNull()?.let { annotation ->
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(annotation.item))
                        context.startActivity(intent)
                    }
            }
        )
    }
}

data class HomeCardData(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
//    val tint: Color? = null,
    val action: () -> Unit
)
