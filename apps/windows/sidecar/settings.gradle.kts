pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
    versionCatalogs {
        create("libs") {
            from(files("../../../apps/android/gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "hopa-windows-sidecar"

include(":core")
project(":core").projectDir = file("../../../packages/core")

include(":capabilities")
project(":capabilities").projectDir = file("../../../packages/capabilities")
