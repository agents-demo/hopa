pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "hopa-android"

include(":app")
include(":testing")
include(":core")
project(":core").projectDir = file("../../packages/core")
include(":capabilities")
project(":capabilities").projectDir = file("../../packages/capabilities")
include(":capabilities-android")
project(":capabilities-android").projectDir = file("capabilities")
include(":data")
project(":data").projectDir = file("../../packages/data")
include(":data-android")
project(":data-android").projectDir = file("data")
