package com.hxgny.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hxgny.app.data.OneColumnSlug
import com.hxgny.app.ui.classes.ClassesViewModel
import com.hxgny.app.ui.onecolumn.OneColumnViewModel

object AppViewModelProvider {
    val classesFactory: ViewModelProvider.Factory = viewModelFactory {
        initializer {
            val app = this.hxgnyApplication()
            ClassesViewModel(app.container.repository)
        }
    }

    fun oneColumnFactory(slug: OneColumnSlug): ViewModelProvider.Factory = viewModelFactory {
        initializer {
            val app = this.hxgnyApplication()
            OneColumnViewModel(slug, app.container.repository)
        }
    }
}

@Suppress("UNCHECKED_CAST")
private fun CreationExtras.hxgnyApplication(): HXGNYApplication {
    return this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as HXGNYApplication
}
