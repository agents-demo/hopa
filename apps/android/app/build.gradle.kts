import java.text.SimpleDateFormat
import java.util.Date
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    id("hopa.ktlint")
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val releaseKeystore = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
val hasReleaseSigning = releaseKeystore?.exists() == true

android {
    namespace = "com.hopa.app"
    compileSdk = 37
    compileSdkMinor = 1

    defaultConfig {
        applicationId = "com.hopa.android"
        minSdk = 29
        targetSdk = 36
        // Every build is a new version: a static code made Android treat the
        // next APK as a reinstall of the same app and refuse it from the picker.
        versionCode = (System.currentTimeMillis() / 1000L).toInt()
        versionName = "0.1.0-" + SimpleDateFormat("yyMMdd-HHmm").format(Date())
        buildConfigField(
            "String",
            "BUILD_TIME",
            "\"" + SimpleDateFormat("yyyy-MM-dd HH:mm").format(Date()) + "\"",
        )
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            testProguardFiles("test-proguard-rules.pro")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            testProguardFiles("test-proguard-rules.pro")
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(project(":agent"))
    implementation(project(":decision"))
    implementation(project(":observation"))
    implementation(project(":runlog"))
    implementation(project(":runtime"))
    implementation(project(":catalog"))
    implementation(project(":capabilities"))
    implementation(project(":platform:ui"))
    implementation(project(":platform:privacy"))
    implementation(project(":platform:share"))
    implementation(project(":engine:llama"))
    implementation(project(":platform:approval"))
    implementation(project(":feature:usage"))
    implementation(project(":feature:memory"))
    implementation(project(":feature:skills"))
    implementation(project(":feature:profiles"))
    implementation(project(":feature:history"))
    implementation(project(":feature:runs"))
    implementation(project(":feature:capabilities"))
    implementation(project(":feature:conversations"))
    implementation(project(":feature:settings"))
    implementation(project(":feature:execution"))
    implementation(project(":feature:chat"))

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(project(":feature:launchpad"))
    implementation(project(":feature:power"))
    implementation(project(":feature:easy"))
    implementation(project(":feature:browser"))
    implementation(project(":data"))
    implementation(project(":contracts"))
    implementation(project(":inference"))
    implementation(project(":bridge"))
    implementation(project(":backend"))
    implementation(project(":stores"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.core.ktx)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testRuntimeOnly(libs.junit.platform.launcher)
    testImplementation(libs.mockwebserver)
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    // androidx.test refers to these annotations; R8 needs them on the test
    // classpath or it refuses to minify the instrumentation APK.
    androidTestImplementation("com.google.errorprone:error_prone_annotations:2.26.0")
}

// A fresh clone has no google-services.json and still has to build; the
// Firebase config is fetched per machine and never committed.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
