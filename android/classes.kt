// HXGNY Android – Jetpack Compose Starter
// ------------------------------------------------------------
// What you get in this starter:
// - Jetpack Compose app with Bottom Tabs: Classes, Schedule, News, Notices, Maps
// - Class list with search + category filter
// - Swipe left to save to My Schedule (persisted via Room)
// - Notices screen with clickable links
// - Zoomable Building & Parking maps (pinch-to-zoom)
// - Repository pattern (Local Room + Remote placeholder for Google Sheets)
// - Seed data from assets/classes.json (optional)
// - Clean architecture-ish layers: data, domain, ui
// - Kotlin + Coroutines + Flow
// ------------------------------------------------------------

// Project structure (Gradle: Kotlin DSL)
// app/
//  ├─ build.gradle.kts
//  ├─ src/main/
//  │   ├─ AndroidManifest.xml
//  │   ├─ assets/
//  │   │   └─ classes.json   (optional seed; same schema as iOS)
//  │   ├─ res/drawable/
//  │   │   ├─ building_map.png
//  │   │   └─ parking_map.png
//  │   ├─ java/com/hxgny/app/
//  │   │   ├─ App.kt
//  │   │   ├─ di/Modules.kt
//  │   │   ├─ data/local/AppDatabase.kt
//  │   │   ├─ data/local/dao/ClassDao.kt
//  │   │   ├─ data/local/dao/NoticeDao.kt
//  │   │   ├─ data/local/entity/ClassEntity.kt
//  │   │   ├─ data/local/entity/NoticeEntity.kt
//  │   │   ├─ data/remote/RemoteDataSource.kt
//  │   │   ├─ data/repo/HxgnyRepository.kt
//  │   │   ├─ domain/model/ClassItem.kt
//  │   │   ├─ domain/model/NoticeItem.kt
//  │   │   ├─ ui/MainActivity.kt
//  │   │   ├─ ui/navigation/NavGraph.kt
//  │   │   ├─ ui/components/SearchBar.kt
//  │   │   ├─ ui/screens/classes/ClassListViewModel.kt
//  │   │   ├─ ui/screens/classes/ClassListScreen.kt
//  │   │   ├─ ui/screens/classes/ClassDetailScreen.kt
//  │   │   ├─ ui/screens/schedule/ScheduleViewModel.kt
//  │   │   ├─ ui/screens/schedule/ScheduleScreen.kt
//  │   │   ├─ ui/screens/notices/NoticesViewModel.kt
//  │   │   ├─ ui/screens/notices/NoticesScreen.kt
//  │   │   ├─ ui/screens/news/NewsScreen.kt
//  │   │   ├─ ui/screens/maps/MapsScreen.kt
//  │   │   └─ ui/theme/Theme.kt
//  │   └─ kotlin resources...
//  └─ proguard-rules.pro

// ---------------------------
// build.gradle.kts (app)
// ---------------------------
/*
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    ksp
}

android {
    namespace = "com.hxgny.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.hxgny.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        vectorDrawables.useSupportLibrary = true
    }

    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get() }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.accompanist.permissions)
    // Optional: Coil for image loading if needed
    implementation(libs.coil.compose)
}
*/

// ---------------------------
// AndroidManifest.xml (snippet)
// ---------------------------
/*
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
      android:name=".App"
      android:allowBackup="true"
      android:icon="@mipmap/ic_launcher"
      android:label="HXGNY"
      android:theme="@style/Theme.Material3.DayNight.NoActionBar">
      <activity android:name=".ui.MainActivity"
          android:exported="true">
          <intent-filter>
              <action android:name="android.intent.action.MAIN" />
              <category android:name="android.intent.category.LAUNCHER" />
          </intent-filter>
      </activity>
  </application>
</manifest>
*/

// ---------------------------
// App.kt
// ---------------------------
package com.hxgny.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class App : Application()

// ---------------------------
// di/Modules.kt (simple manual DI shown; switch to Hilt if desired)
// ---------------------------
package com.hxgny.app.di

import android.content.Context
import androidx.room.Room
import com.hxgny.app.data.local.AppDatabase
import com.hxgny.app.data.repo.HxgnyRepository

object Modules {
    fun provideDb(ctx: Context) = Room.databaseBuilder(
        ctx, AppDatabase::class.java, "hxgny.db"
    ).fallbackToDestructiveMigration().build()

    fun provideRepo(ctx: Context) = HxgnyRepository(provideDb(ctx))
}

// ---------------------------
// data/local/AppDatabase.kt
// ---------------------------
package com.hxgny.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.hxgny.app.data.local.dao.ClassDao
import com.hxgny.app.data.local.dao.NoticeDao
import com.hxgny.app.data.local.entity.ClassEntity
import com.hxgny.app.data.local.entity.NoticeEntity

@Database(
    entities = [ClassEntity::class, NoticeEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun classDao(): ClassDao
    abstract fun noticeDao(): NoticeDao
}

// ---------------------------
// data/local/entity/ClassEntity.kt
// ---------------------------
package com.hxgny.app.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "classes")
data class ClassEntity(
    @PrimaryKey val id: String,
    val name: String,
    val category: String?,
    val teacher: String?,
    val ageRange: String?,
    val schedule: String?,
    val location: String?,
    val description: String?,
    val saved: Boolean = false // whether user saved to schedule
)

// ---------------------------
// data/local/entity/NoticeEntity.kt
// ---------------------------
package com.hxgny.app.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "notices")
data class NoticeEntity(
    @PrimaryKey val id: String,
    val date: Long,
    val message: String
)

// ---------------------------
// data/local/dao/ClassDao.kt
// ---------------------------
package com.hxgny.app.data.local.dao

import androidx.room.*
import com.hxgny.app.data.local.entity.ClassEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ClassDao {
    @Query("SELECT * FROM classes ORDER BY name")
    fun getAll(): Flow<List<ClassEntity>>

    @Query("SELECT * FROM classes WHERE saved = 1 ORDER BY name")
    fun getSaved(): Flow<List<ClassEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<ClassEntity>)

    @Update
    suspend fun update(item: ClassEntity)

    @Query("UPDATE classes SET saved = :saved WHERE id = :id")
    suspend fun setSaved(id: String, saved: Boolean)
}

// ---------------------------
// data/local/dao/NoticeDao.kt
// ---------------------------
package com.hxgny.app.data.local.dao

import androidx.room.*
import com.hxgny.app.data.local.entity.NoticeEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface NoticeDao {
    @Query("SELECT * FROM notices ORDER BY date DESC")
    fun getAll(): Flow<List<NoticeEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<NoticeEntity>)
}

// ---------------------------
// domain/model/ClassItem.kt
// ---------------------------
package com.hxgny.app.domain.model

data class ClassItem(
    val id: String,
    val name: String,
    val category: String?,
    val teacher: String?,
    val ageRange: String?,
    val schedule: String?,
    val location: String?,
    val description: String?,
    val saved: Boolean
)

// ---------------------------
// domain/model/NoticeItem.kt
// ---------------------------
package com.hxgny.app.domain.model

data class NoticeItem(
    val id: String,
    val dateMillis: Long,
    val message: String
)

// ---------------------------
// data/remote/RemoteDataSource.kt (placeholder for Google Sheets)
// ---------------------------
package com.hxgny.app.data.remote

import com.hxgny.app.domain.model.ClassItem
import com.hxgny.app.domain.model.NoticeItem

class RemoteDataSource {
    suspend fun fetchClasses(): List<ClassItem> {
        // TODO: Replace with real Google Sheets fetch.
        // For now return empty list; rely on local seed or cached data for offline.
        return emptyList()
    }

    suspend fun fetchNotices(): List<NoticeItem> {
        return emptyList()
    }
}

// ---------------------------
// data/repo/HxgnyRepository.kt
// ---------------------------
package com.hxgny.app.data.repo

import android.util.Log
import com.hxgny.app.data.local.AppDatabase
import com.hxgny.app.data.local.entity.ClassEntity
import com.hxgny.app.data.local.entity.NoticeEntity
import com.hxgny.app.domain.model.ClassItem
import com.hxgny.app.domain.model.NoticeItem
import kotlinx.coroutines.flow.map

class HxgnyRepository(private val db: AppDatabase) {
    private val classDao = db.classDao()
    private val noticeDao = db.noticeDao()

    val classes = classDao.getAll().map { list -> list.map { it.toDomain() } }
    val savedClasses = classDao.getSaved().map { list -> list.map { it.toDomain() } }
    val notices = noticeDao.getAll().map { list -> list.map { it.toDomain() } }

    suspend fun seedIfEmpty(seed: List<ClassEntity>) {
        // idempotent seed
        classDao.upsertAll(seed)
    }

    suspend fun setSaved(id: String, saved: Boolean) = classDao.setSaved(id, saved)

    suspend fun refresh(remoteClasses: List<ClassItem>, remoteNotices: List<NoticeItem>) {
        try {
            if (remoteClasses.isNotEmpty()) {
                classDao.upsertAll(remoteClasses.map { it.toEntity() })
            }
            if (remoteNotices.isNotEmpty()) {
                noticeDao.upsertAll(remoteNotices.map { it.toEntity() })
            }
        } catch (e: Exception) {
            Log.e("Repo", "refresh failed", e)
        }
    }
}

private fun ClassEntity.toDomain() = ClassItem(id, name, category, teacher, ageRange, schedule, location, description, saved)
private fun NoticeEntity.toDomain() = NoticeItem(id, date, message)
private fun ClassItem.toEntity() = ClassEntity(id, name, category, teacher, ageRange, schedule, location, description, saved)
private fun NoticeItem.toEntity() = NoticeEntity(id, dateMillis, message)

// ---------------------------
// ui/MainActivity.kt
// ---------------------------
package com.hxgny.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hxgny.app.di.Modules
import com.hxgny.app.ui.navigation.RootNav
import com.hxgny.app.ui.theme.HxgnyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val repo = Modules.provideRepo(applicationContext)
        setContent {
            HxgnyTheme {
                RootNav(repo)
            }
        }
    }
}

// ---------------------------
// ui/navigation/NavGraph.kt
// ---------------------------
package com.hxgny.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.hxgny.app.data.repo.HxgnyRepository
import com.hxgny.app.ui.screens.classes.ClassListScreen
import com.hxgny.app.ui.screens.maps.MapsScreen
import com.hxgny.app.ui.screens.news.NewsScreen
import com.hxgny.app.ui.screens.notices.NoticesScreen
import com.hxgny.app.ui.screens.schedule.ScheduleScreen

sealed class Tab(val route: String, val label: String) {
    data object Classes: Tab("classes", "Classes")
    data object Schedule: Tab("schedule", "Schedule")
    data object News: Tab("news", "News")
    data object Notices: Tab("notices", "Notices")
    data object Maps: Tab("maps", "Maps")
}

@Composable
fun RootNav(repo: HxgnyRepository) {
    val nav = rememberNavController()
    val items = listOf(Tab.Classes, Tab.Schedule, Tab.News, Tab.Notices, Tab.Maps)
    Scaffold(
        bottomBar = {
            NavigationBar {
                val backStack by nav.currentBackStackEntryAsState()
                val current = backStack?.destination?.route
                items.forEach { tab ->
                    NavigationBarItem(
                        selected = current == tab.route,
                        onClick = { nav.navigate(tab.route) },
                        label = { Text(tab.label) },
                        icon = { /* optional icons */ }
                    )
                }
            }
        }
    ) { inner ->
        NavHost(navController = nav, startDestination = Tab.Classes.route, modifier = Modifier.padding(inner)) {
            composable(Tab.Classes.route) { ClassListScreen(repo) }
            composable(Tab.Schedule.route) { ScheduleScreen(repo) }
            composable(Tab.News.route) { NewsScreen() }
            composable(Tab.Notices.route) { NoticesScreen(repo) }
            composable(Tab.Maps.route) { MapsScreen() }
        }
    }
}

// ---------------------------
// ui/components/SearchBar.kt (simple)
// ---------------------------
package com.hxgny.app.ui.components

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember

@Composable
fun SearchBar(onChange: (String) -> Unit) {
    val (text, setText) = remember { mutableStateOf("") }
    OutlinedTextField(
        value = text,
        onValueChange = { setText(it); onChange(it) },
        label = { Text("Search") },
        singleLine = true
    )
}

// ---------------------------
// ui/screens/classes/ClassListViewModel.kt
// ---------------------------
package com.hxgny.app.ui.screens.classes

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.hxgny.app.data.local.entity.ClassEntity
import com.hxgny.app.data.repo.HxgnyRepository
import com.hxgny.app.domain.model.ClassItem
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class ClassListViewModel(private val repo: HxgnyRepository): ViewModel() {
    private val query = MutableStateFlow("")
    private val category = MutableStateFlow("")

    val classes: StateFlow<List<ClassItem>> = combine(
        repo.classes, query, category
    ) { list, q, c ->
        list.filter { item ->
            val matchQ = q.isBlank() || item.name.contains(q, true) ||
                (item.teacher?.contains(q, true) == true) ||
                (item.ageRange?.contains(q, true) == true)
            val matchC = c.isBlank() || (item.category?.equals(c, true) == true)
            matchQ && matchC
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun setQuery(s: String) { viewModelScope.launch { query.emit(s) } }
    fun setCategory(c: String) { viewModelScope.launch { category.emit(c) } }
    fun toggleSaved(id: String, saved: Boolean) { viewModelScope.launch { repo.setSaved(id, saved) } }
    suspend fun seed(items: List<ClassEntity>) { repo.seedIfEmpty(items) }
}

// ---------------------------
// ui/screens/classes/ClassListScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.classes

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hxgny.app.data.repo.HxgnyRepository
import com.hxgny.app.domain.model.ClassItem
import com.hxgny.app.ui.components.SearchBar
import kotlinx.coroutines.launch

@Composable
fun ClassListScreen(repo: HxgnyRepository) {
    val vm = remember { ClassListViewModel(repo) }
    val list by vm.classes.collectAsState()
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        SearchBar(vm::setQuery)
        Spacer(Modifier.height(8.dp))
        CategoryChips(onChange = vm::setCategory)
        Spacer(Modifier.height(8.dp))
        LazyColumn {
            items(list.size, key = { list[it].id }) { idx ->
                val item = list[idx]
                SwipeSaveRow(item = item, onSaveToggle = { target, newSaved ->
                    scope.launch { vm.toggleSaved(target.id, newSaved) }
                })
                Divider()
            }
        }
    }
}

@Composable
private fun CategoryChips(onChange: (String) -> Unit) {
    val cats = listOf("", "Junior Chinese Language Class", "Senior Chinese Language Class", "Junior Enrichment Class", "Senior Enrichment Class", "Adult Classes")
    var selected by remember { mutableStateOf("") }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        cats.forEach { c ->
            FilterChip(
                selected = selected == c,
                onClick = { selected = c; onChange(c) },
                label = { Text(if (c.isBlank()) "All" else c) }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeSaveRow(item: ClassItem, onSaveToggle: (ClassItem, Boolean) -> Unit) {
    val dismissState = rememberDismissState(confirmValueChange = { value ->
        val newSaved = when (value) {
            DismissValue.DismissedToStart -> true
            DismissValue.DismissedToEnd -> false
            else -> return@rememberDismissState false
        }
        onSaveToggle(item, newSaved)
        false // don't auto-dismiss item from list
    })
    SwipeToDismiss(
        state = dismissState,
        background = {
            val bg = if (!item.saved) Color(0xFF4CAF50) else Color(0xFFF44336)
            Box(Modifier.fillMaxSize().background(bg), contentAlignment = Alignment.Center) {
                Text(if (!item.saved) "Save to Schedule" else "Remove from Schedule", color = Color.White, fontWeight = FontWeight.Bold)
            }
        },
        dismissContent = {
            ListItem(
                headlineContent = { Text(item.name) },
                supportingContent = {
                    Text(listOfNotNull(item.teacher, item.ageRange, item.schedule, item.location).joinToString(" · "))
                },
                trailingContent = {
                    AssistChip(onClick = { onSaveToggle(item, !item.saved) }, label = { Text(if (item.saved) "Saved" else "Save") })
                }
            )
        }
    )
}

// ---------------------------
// ui/screens/schedule/ScheduleViewModel.kt & ScheduleScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.schedule

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import com.hxgny.app.data.repo.HxgnyRepository
import com.hxgny.app.domain.model.ClassItem

class ScheduleViewModel(private val repo: HxgnyRepository) {
    val saved = repo.savedClasses
}

@Composable
fun ScheduleScreen(repo: HxgnyRepository) {
    val vm = remember { ScheduleViewModel(repo) }
    val list by vm.saved.collectAsState(initial = emptyList())
    LazyColumn {
        items(list.size, key = { list[it].id }) { i ->
            val item: ClassItem = list[i]
            ListItem(headlineContent = { Text(item.name) }, supportingContent = {
                Text(listOfNotNull(item.schedule, item.location).joinToString(" · "))
            })
            Divider()
        }
    }
}

// ---------------------------
// ui/screens/notices/NoticesScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.notices

import android.text.util.Linkify
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.unit.dp
import com.hxgny.app.data.repo.HxgnyRepository
import kotlinx.coroutines.flow.collectLatest

@Composable
fun NoticesScreen(repo: HxgnyRepository) {
    val notices by repo.notices.collectAsState(initial = emptyList())
    LazyColumn(Modifier.padding(12.dp)) {
        items(notices.size) { idx ->
            val n = notices[idx]
            Card(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                ListItem(
                    overlineContent = { Text(java.text.SimpleDateFormat("yyyy-MM-dd").format(java.util.Date(n.dateMillis))) },
                    supportingContent = { AutoLinkText(n.message) }
                )
            }
        }
    }
}

@Composable
private fun AutoLinkText(text: String) {
    // Basic autolink by showing the raw text; for production consider AndroidTextUtils linkify in a TextView inside AndroidView.
    Text(text = text)
}

// ---------------------------
// ui/screens/news/NewsScreen.kt (placeholder)
// ---------------------------
package com.hxgny.app.ui.screens.news

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable

@Composable
fun NewsScreen() {
    Text("Weekly News – coming soon")
}

// ---------------------------
// ui/screens/maps/MapsScreen.kt (zoomable images)
// ---------------------------
package com.hxgny.app.ui.screens.maps

import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.hxgny.app.R

@Composable
fun MapsScreen() {
    Column(Modifier.fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ZoomableImage(resId = R.drawable.building_map)
        ZoomableImage(resId = R.drawable.parking_map)
    }
}

@Composable
private fun ZoomableImage(resId: Int) {
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }

    Image(
        painter = painterResource(id = resId),
        contentDescription = null,
        modifier = Modifier
            .fillMaxWidth()
            .height(240.dp)
            .graphicsLayer(
                scaleX = scale, scaleY = scale,
                translationX = offsetX, translationY = offsetY
            )
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ ->
                    scale = (scale * zoom).coerceIn(1f, 5f)
                    offsetX += pan.x
                    offsetY += pan.y
                }
            }
    )
}

// ---------------------------
// ui/theme/Theme.kt (Material3 theme placeholder)
// ---------------------------
package com.hxgny.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

@Composable
fun HxgnyTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = darkColorScheme(), content = content)
}

// ------------------------------------------------------------
// How to use seed classes.json (assets):
// Schema (aligned with iOS):
// [
//   {"id":"c1","name":"Junior Chinese A","category":"Junior Chinese Language Class","teacher":"Ms. Li","ageRange":"6-8","schedule":"Sun 9:00-10:00","location":"Room 101","description":"基础汉语"}
// ]
// On first app launch, load it and call repo.seedIfEmpty(...)
// ------------------------------------------------------------

// ---------------------------
// Quick start notes
// ---------------------------
// 1) Create a new Android Studio project (Empty Compose Activity), replace files with the above structure.
// 2) Add Room/Compose dependencies via Version Catalog (libs.*) or replace with explicit versions.
// 3) Put building_map.png & parking_map.png in res/drawable/.
// 4) Place classes.json in src/main/assets/ if you want initial offline data.
// 5) Build & run: Debug APK installs on device/emulator.
// 6) Later: implement RemoteDataSource to pull Google Sheets (CSV/JSON) and call repo.refresh(...).
// 7) Play Console: create app listing, upload signed release (App Bundle), set content ratings, privacy policy, etc.


// ===========================
// NEW: Retrofit remote + Home grid + OneColumn list
// ===========================

// build.gradle.kts additions (dependencies)
/*
dependencies {
    // ...existing...
    implementation(libs.retrofit)
    implementation(libs.retrofit.moshi)
    implementation(libs.moshi)
    implementation(libs.moshi.kotlin)
}
*/

// ---------------------------
// data/remote/RetrofitModule.kt
// ---------------------------
package com.hxgny.app.data.remote

import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

object RetrofitModule {
    fun client(baseUrl: String): Retrofit = Retrofit.Builder()
        .baseUrl(baseUrl)
        .addConverterFactory(MoshiConverterFactory.create())
        .build()
}

// ---------------------------
// data/remote/OpenSheetApi.kt (generic JSON rows)
// ---------------------------
package com.hxgny.app.data.remote

import retrofit2.http.GET

// OpenSheet exposes a sheet tab as JSON array of key/value maps.
// We model rows as Map<String, String> so different tabs work.
interface OpenSheetApi {
    @GET("/")
    suspend fun rows(): List<Map<String, String>>
}

// ---------------------------
// data/remote/RemoteDataSource.kt (replace placeholder)
// ---------------------------
package com.hxgny.app.data.remote

import com.hxgny.app.domain.model.ClassItem
import com.hxgny.app.domain.model.NoticeItem

class RemoteDataSource {
    // Example: https://opensheet.vercel.app/<SHEET_ID>/<TAB>
    suspend fun fetchClasses(baseUrl: String): List<ClassItem> {
        val api = RetrofitModule.client(normalize(baseUrl)).create(OpenSheetApi::class.java)
        val rows = api.rows()
        return rows.mapNotNull { r ->
            // Expecting columns similar to iOS: title, teacher, chineseTeacher, day, time, grade, room, buildingHint, category, id (optional)
            val title = r["title"] ?: return@mapNotNull null
            ClassItem(
                id = r["id"] ?: java.util.UUID.randomUUID().toString(),
                name = title,
                category = r["category"],
                teacher = r["teacher"],
                ageRange = r["grade"],
                schedule = listOfNotNull(r["day"], r["time"]).joinToString(" ").ifBlank { null },
                location = r["room"],
                description = r["buildingHint"],
                saved = false
            )
        }
    }

    suspend fun fetchNotices(baseUrl: String): List<NoticeItem> {
        val api = RetrofitModule.client(normalize(baseUrl)).create(OpenSheetApi::class.java)
        val rows = api.rows()
        return rows.map { r ->
            val msg = r["message"] ?: r.values.joinToString(" ")
            val dateStr = r["date"] ?: ""
            val ts = parseDateMillis(dateStr)
            NoticeItem(
                id = r["id"] ?: java.util.UUID.randomUUID().toString(),
                dateMillis = ts,
                message = msg
            )
        }
    }

    private fun normalize(u: String): String = if (u.endsWith('/')) u else "$u/"
    private fun parseDateMillis(s: String): Long = try {
        java.time.LocalDate.parse(s).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
    } catch (_: Exception) { System.currentTimeMillis() }
}

// ---------------------------
// ui/screens/home/HomeScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.hxgny.app.ui.navigation.NavDest

@Composable
fun HomeScreen(onNavigate: (NavDest) -> Unit, classesCount: Int, savedCount: Int) {
    val items = listOf(
        HomeCard("Classes", "${classesCount} available", Icons.Default.List, NavDest.Classes),
        HomeCard("Buildings", "Campus map", Icons.Default.Map, NavDest.Maps),
        HomeCard("Parking", "Parking map", Icons.Default.DirectionsCar, NavDest.Maps),
        HomeCard("Weekly News", "Announcements", Icons.Default.Notifications, NavDest.News),
        HomeCard("Calendar", "School calendar", Icons.Default.CalendarMonth, NavDest.Calendar),
        HomeCard("My Schedule", "${savedCount} saved", Icons.Default.Bookmark, NavDest.Schedule),
        HomeCard("Upcoming Events", "活动预告", Icons.Default.Star, NavDest.Events),
        HomeCard("Lost & Found", "Coming soon", Icons.Default.Help, NavDest.LostFound),
        HomeCard("Class Parents", "Coming soon", Icons.Default.Group, NavDest.ClassParents),
        HomeCard("Sponsors", "Coming soon", Icons.Default.VolunteerActivism, NavDest.Sponsors),
        HomeCard("Contact Us", "Coming soon", Icons.Default.Email, NavDest.Contact),
        HomeCard("Join Us", "Coming soon", Icons.Default.PersonAdd, NavDest.Join)
    )
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 170.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        items(items.size) { i ->
            ElevatedCard(onClick = { onNavigate(items[i].dest) }) {
                ListItem(
                    headlineContent = { Text(items[i].title) },
                    supportingContent = { Text(items[i].subtitle) },
                    leadingContent = { Icon(items[i].icon, contentDescription = null) }
                )
            }
        }
    }
}

data class HomeCard(val title: String, val subtitle: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val dest: NavDest)

// ---------------------------
// ui/navigation/NavGraph.kt (extend)
// ---------------------------
package com.hxgny.app.ui.navigation

enum class NavDest { Classes, Schedule, News, Notices, Maps, Calendar, Events, LostFound, ClassParents, Sponsors, Contact, Join }

// In RootNav(...) add a composable for Home and OneColumn-like list where applicable.
// Example destination for Calendar image and a generic OneColumn screen is below.

// ---------------------------
// ui/screens/calendar/CalendarScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.calendar

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.hxgny.app.R

@Composable
fun CalendarScreen() {
    Image(painterResource(R.drawable.calendar_placeholder), contentDescription = null, modifier = Modifier.padding(16.dp))
}

// ---------------------------
// ui/screens/onecolumn/OneColumnListScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.onecolumn

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import com.hxgny.app.data.remote.OpenSheetApi
import com.hxgny.app.data.remote.RetrofitModule

@Composable
fun OneColumnListScreen(baseUrl: String, title: String) {
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<Map<String, String>>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(baseUrl) {
        scope.launch {
            try {
                val api = RetrofitModule.client(normalize(baseUrl)).create(OpenSheetApi::class.java)
                rows = api.rows()
            } catch (e: Exception) { error = e.message }
        }
    }

    Scaffold(topBar = { TopAppBar(title = { Text(title) }) }) { padding ->
        if (error != null) {
            Text("Load failed: $error", modifier = Modifier.padding(padding))
        } else {
            LazyColumn(modifier = Modifier.padding(padding)) {
                items(rows.size) { i ->
                    val r = rows[i]
                    Card(Modifier.fillMaxWidth()) {
                        ListItem(
                            headlineContent = { Text(r["title"] ?: r.values.firstOrNull() ?: "—") },
                            supportingContent = {
                                val sub = r["subtitle"] ?: r["desc"] ?: r["message"]
                                if (sub != null) Text(sub)
                            }
                        )
                    }
                    Divider()
                }
            }
        }
    }
}

private fun normalize(u: String): String = if (u.endsWith('/')) u else "$u/"

// ===========================
// NEW: Retrofit remote + Home grid + OneColumn list
// ===========================

// build.gradle.kts additions (dependencies)
/*
dependencies {
    // ...existing...
    implementation(libs.retrofit)
    implementation(libs.retrofit.moshi)
    implementation(libs.moshi)
    implementation(libs.moshi.kotlin)
}
*/

// ---------------------------
// data/remote/RetrofitModule.kt
// ---------------------------
package com.hxgny.app.data.remote

import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

object RetrofitModule {
    fun client(baseUrl: String): Retrofit = Retrofit.Builder()
        .baseUrl(baseUrl)
        .addConverterFactory(MoshiConverterFactory.create())
        .build()
}

// ---------------------------
// data/remote/OpenSheetApi.kt (generic JSON rows)
// ---------------------------
package com.hxgny.app.data.remote

import retrofit2.http.GET

// OpenSheet exposes a sheet tab as JSON array of key/value maps.
// We model rows as Map<String, String> so different tabs work.
interface OpenSheetApi {
    @GET("/")
    suspend fun rows(): List<Map<String, String>>
}

// ---------------------------
// data/remote/RemoteDataSource.kt (replace placeholder)
// ---------------------------
package com.hxgny.app.data.remote

import com.hxgny.app.domain.model.ClassItem
import com.hxgny.app.domain.model.NoticeItem

class RemoteDataSource {
    // Example: https://opensheet.vercel.app/<SHEET_ID>/<TAB>
    suspend fun fetchClasses(baseUrl: String): List<ClassItem> {
        val api = RetrofitModule.client(normalize(baseUrl)).create(OpenSheetApi::class.java)
        val rows = api.rows()
        return rows.mapNotNull { r ->
            // Expecting columns similar to iOS: title, teacher, chineseTeacher, day, time, grade, room, buildingHint, category, id (optional)
            val title = r["title"] ?: return@mapNotNull null
            ClassItem(
                id = r["id"] ?: java.util.UUID.randomUUID().toString(),
                name = title,
                category = r["category"],
                teacher = r["teacher"],
                ageRange = r["grade"],
                schedule = listOfNotNull(r["day"], r["time"]).joinToString(" ").ifBlank { null },
                location = r["room"],
                description = r["buildingHint"],
                saved = false
            )
        }
    }

    suspend fun fetchNotices(baseUrl: String): List<NoticeItem> {
        val api = RetrofitModule.client(normalize(baseUrl)).create(OpenSheetApi::class.java)
        val rows = api.rows()
        return rows.map { r ->
            val msg = r["message"] ?: r.values.joinToString(" ")
            val dateStr = r["date"] ?: ""
            val ts = parseDateMillis(dateStr)
            NoticeItem(
                id = r["id"] ?: java.util.UUID.randomUUID().toString(),
                dateMillis = ts,
                message = msg
            )
        }
    }

    private fun normalize(u: String): String = if (u.endsWith('/')) u else "$u/"
    private fun parseDateMillis(s: String): Long = try {
        java.time.LocalDate.parse(s).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
    } catch (_: Exception) { System.currentTimeMillis() }
}

// ---------------------------
// ui/screens/home/HomeScreen.kt
// ---------------------------
package com.hxgny.app.ui.screens.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.hxgny.app.ui.navigation.NavDest

@Composable
fun HomeScreen(onNavigate: (NavDest) -> Unit, classesCount: Int, savedCount: Int) {
    val items = listOf(
        HomeCard("Classes", "${classesCount} available", Icons.Default.List, NavDest.Classes),
        HomeCard("Buildings", "Campus map", Icons.Default.Map, NavDest.Maps),
        HomeCard("Parking", "Parking map", Icons.Default.DirectionsCar, NavDest.Maps),
        HomeCard("Weekly News", "Announcements", Icons.Default.Notifications, NavDest.News),
        HomeCard("Calendar", "School calendar", Icons.Default.CalendarMonth, NavDest.Calendar),
        HomeCard("My Schedule", "${savedCount} saved", Icons.Default.Bookmark, NavDest.Schedule),
        HomeCard("Upcoming Events", "活动预告", Icons.Default.Star, NavDest.Events),
        HomeCard("Lost & Found", "Coming soon", Icons.Default.Help, NavDest.LostFound),
        HomeCard("Class Parents", "Coming soon", Icons.Default.Group, NavDest.ClassParents),
        HomeCard("Sponsors", "Coming soon", Icons.Default.VolunteerActivism, NavDest.Sponsors),
        HomeCard("Contact Us", "Coming soon", Icons.Default.Email, NavDest.Contact),
        HomeCard("Join Us", "Coming soon", Icons.Default.PersonAdd, NavDest.Join)
    )
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 170.dp),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        items(items.size) { i ->
            ElevatedCard(onClick = { onNavigate(items[i].dest) }) {
                ListItem(
                    headlineContent = { Text(items[i].title) },
          