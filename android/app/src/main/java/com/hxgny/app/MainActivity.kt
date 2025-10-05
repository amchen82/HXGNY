package com.hxgny.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hxgny.app.ui.classes.ClassesViewModel
import com.hxgny.app.ui.navigation.HXGNYApp
import com.hxgny.app.ui.splash.SplashScreen
import com.hxgny.app.ui.theme.HXGNYTheme
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HXGNYTheme {
                val classesViewModel: ClassesViewModel = viewModel(factory = AppViewModelProvider.classesFactory)
                val state by classesViewModel.state.collectAsStateWithLifecycle()
                var showSplash by remember { mutableStateOf(true) }
                LaunchedEffect(Unit) {
                    classesViewModel.refresh()
                    delay(600)
                    showSplash = false
                }
                if (showSplash && state.isLoading) {
                    SplashScreen()
                } else {
                    HXGNYApp(classesViewModel)
                }
            }
        }
    }
}
