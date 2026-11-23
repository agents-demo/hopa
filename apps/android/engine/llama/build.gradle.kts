plugins {
    alias(libs.plugins.android.library)
    id("hopa.ktlint")
}

android {
    namespace = "com.hopa.localmodel"
    compileSdk = 37
    compileSdkMinor = 1
    ndkVersion = "28.2.13676358"

    defaultConfig {
        minSdk = 29

        ndk {
            // The phone ships arm64 only; the emulator needs x86_64 to be testable.
            abiFilters += listOf("arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":inference"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.okhttp)

    testImplementation(libs.junit)
}
