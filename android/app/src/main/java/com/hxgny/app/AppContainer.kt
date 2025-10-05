package com.hxgny.app

import android.content.Context
import com.hxgny.app.data.HxgnyRepository

class AppContainer(context: Context) {
    val repository: HxgnyRepository = HxgnyRepository(context)
}
