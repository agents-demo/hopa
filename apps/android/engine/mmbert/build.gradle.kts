plugins {
    alias(libs.plugins.android.library)
    id("hopa.ktlint")
}

android {
    namespace = "com.hopa.mmbert"
    compileSdk = 37
    compileSdkMinor = 1

    defaultConfig {
        minSdk = 29
    }

    sourceSets.getByName("test").resources.srcDir("src/main/assets")

    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":contracts"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.okhttp)
    implementation(libs.onnxruntime.android)

    testImplementation(libs.junit)
    testRuntimeOnly(libs.junit.platform.launcher)
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("com.google.errorprone:error_prone_annotations:2.27.1")
}
