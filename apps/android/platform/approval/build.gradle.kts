plugins {
    alias(libs.plugins.android.library)
    id("hopa.ktlint")
}

android {
    namespace = "com.hopa.approval"
    compileSdk = 37
    compileSdkMinor = 1

    defaultConfig {
        minSdk = 29
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
    api(project(":contracts"))
    api(project(":stores"))
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
    testRuntimeOnly(libs.junit.platform.launcher)
}
