package com.hopa.app

import android.app.Application
import com.hopa.app.di.AppContainer

class HopaApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
