plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    id("hopa.ktlint")
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.hopa.feature.settings"
    compileSdk = 37
    compileSdkMinor = 1

    defaultConfig {
        minSdk = 29
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(project(":platform:ui"))
    api(project(":engine:llama"))
    api(project(":engine:mmbert"))

    api(project(":contracts"))
    api(project(":stores"))
    api(project(":decision"))
    api(project(":inference"))
    api(project(":capabilities"))
    api(project(":backend"))
    api(project(":runtime"))
    api(project(":bridge"))

    testImplementation(libs.junit)
    testRuntimeOnly(libs.junit.platform.launcher)
}
