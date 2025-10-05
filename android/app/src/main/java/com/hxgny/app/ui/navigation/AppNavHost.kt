package com.hxgny.app.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
//import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack

//import androidx.compose.material.icons.filled.ArrowBack

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.hxgny.app.AppViewModelProvider
import com.hxgny.app.R
import com.hxgny.app.data.OneColumnSlug
import com.hxgny.app.model.ClassItem
import com.hxgny.app.ui.classes.ClassDetailScreen
import com.hxgny.app.ui.classes.ClassListScreen
import com.hxgny.app.ui.classes.ClassesUiState
import com.hxgny.app.ui.classes.ClassesViewModel
import com.hxgny.app.ui.components.UpdateButton
import com.hxgny.app.ui.home.HomeAction
import com.hxgny.app.ui.home.HomeScreen
import com.hxgny.app.ui.maps.ZoomableImageScreen
import com.hxgny.app.ui.onecolumn.OneColumnScreen
import com.hxgny.app.ui.schedule.ScheduleScreen

private const val ROUTE_HOME = "home"
private const val ROUTE_CLASSES = "classes"
private const val ROUTE_CLASS_DETAIL = "class_detail/{classId}"
private const val ROUTE_SCHEDULE = "schedule"
private const val ROUTE_MAP = "map/{kind}"
private const val ROUTE_ONE_COLUMN = "onecolumn/{slug}"

@Composable
fun HXGNYApp(classesViewModel: ClassesViewModel) {
    val navController = rememberNavController()
    val classesState by classesViewModel.state.collectAsStateWithLifecycle()

    Column {
        Box(modifier = androidx.compose.ui.Modifier.weight(1f)) {
            AppNavHost(
                navController = navController,
                classesViewModel = classesViewModel,
                classesState = classesState
            )
        }
        UpdateButton()
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun AppNavHost(
    navController: NavHostController,
    classesViewModel: ClassesViewModel,
    classesState: ClassesUiState
) {
    NavHost(navController = navController, startDestination = ROUTE_HOME) {
        composable(ROUTE_HOME) {
            HomeScreen(
                classesCount = classesState.allClasses.size,
                savedCount = classesState.saved.size,
                onAction = { action ->
                    when (action) {
                        HomeAction.Classes -> navController.navigate(ROUTE_CLASSES)
                        HomeAction.Schedule -> navController.navigate(ROUTE_SCHEDULE)
                        HomeAction.Buildings -> navController.navigate("map/building")
                        HomeAction.Parking -> navController.navigate("map/parking")
                        HomeAction.Calendar -> navController.navigate("map/calendar")
                        is HomeAction.OneColumn -> navController.navigate("onecolumn/" + action.slug.slug)
                        HomeAction.WeeklyNews -> navController.navigate("onecolumn/" + OneColumnSlug.WeeklyNews.slug)
                    }
                }
            )
        }
        composable(ROUTE_CLASSES) {
            ClassListScreen(
                state = classesState,
                onQueryChanged = classesViewModel::setQuery,
                onCategoryChanged = classesViewModel::selectCategory,
                onToggleOnSite = classesViewModel::toggleOnSiteOnly,
                onToggleSaved = classesViewModel::toggleSaved,
                onRefresh = classesViewModel::refresh,
                onNavigateUp = { navController.popBackStack() },
                onOpenDetails = { item: ClassItem ->
                    navController.navigate("class_detail/" + item.id)
                }
            )
        }
        composable(
            route = ROUTE_CLASS_DETAIL,
            arguments = listOf(navArgument("classId") { type = NavType.StringType })
        ) { entry ->
            val id = entry.arguments?.getString("classId")
            val item = id?.let { classesViewModel.classById(it) }
            if (item != null) {
                ClassDetailScreen(item = item, onNavigateUp = { navController.popBackStack() })
            } else {
                androidx.compose.material3.Scaffold(
                    topBar = {
                        androidx.compose.material3.TopAppBar(
                            title = { androidx.compose.material3.Text("Details") },
                            navigationIcon = {
                                androidx.compose.material3.IconButton(onClick = { navController.popBackStack() }) {
                                    androidx.compose.material3.Icon(
                                        imageVector =  Icons.AutoMirrored.Filled.ArrowBack,
                                        contentDescription = "Back"
                                    )
                                }
                            }
                        )
                    }
                ) { padding ->
                    androidx.compose.material3.Text(
                        text = "Class not found",
                        modifier = androidx.compose.ui.Modifier.padding(padding).padding(24.dp)
                    )
                }
            }
        }
        composable(ROUTE_SCHEDULE) {
            ScheduleScreen(
                saved = classesState.saved,
                onRemove = { classesViewModel.toggleSaved(it) },
                onNavigateUp = { navController.popBackStack() }
            )
        }
        composable(
            route = ROUTE_MAP,
            arguments = listOf(navArgument("kind") { type = NavType.StringType })
        ) { entry ->
            val kind = entry.arguments?.getString("kind") ?: "building"
            val destination = MapDestination.from(kind)
            ZoomableImageScreen(
                imageRes = destination.imageRes,
                title = destination.title,
                onNavigateUp = { navController.popBackStack() }
            )
        }
        composable(
            route = ROUTE_ONE_COLUMN,
            arguments = listOf(navArgument("slug") { type = NavType.StringType })
        ) { entry ->
            val slugName = entry.arguments?.getString("slug") ?: OneColumnSlug.JoinUs.slug
            val slug = OneColumnSlug.values().firstOrNull { it.slug == slugName } ?: OneColumnSlug.JoinUs
            val viewModel: com.hxgny.app.ui.onecolumn.OneColumnViewModel = viewModel(
                factory = AppViewModelProvider.oneColumnFactory(slug)
            )
            val state by viewModel.state.collectAsStateWithLifecycle()
            OneColumnScreen(
                title = slug.displayTitle(),
                state = state,
                onRefresh = viewModel::refresh,
                onNavigateUp = { navController.popBackStack() }
            )
        }
    }
}

private enum class MapDestination(val kind: String, val imageRes: Int, val title: String) {
    BUILDING("building", R.drawable.building_map, "Building Map"),
    PARKING("parking", R.drawable.parking_map, "Parking Map"),
    CALENDAR("calendar", R.drawable.hxgny_calendar, "Calendar");

    companion object {
        fun from(kind: String): MapDestination = values().firstOrNull { it.kind == kind } ?: BUILDING
    }
}

private fun OneColumnSlug.displayTitle(): String = when (this) {
    OneColumnSlug.SchoolIntro -> "School Intro"
    OneColumnSlug.JoinUs -> "Join Us"
    OneColumnSlug.LostFound -> "Lost & Found"
    OneColumnSlug.Sponsors -> "Sponsors"
    OneColumnSlug.Contact -> "Contact Us"
    OneColumnSlug.WeeklyNews -> "Weekly News"
}
