pluginManagement {
    includeBuild("../../../build-logic")
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

include(":catalog")
project(":catalog").projectDir = file("../../../core/catalog")

include(":contracts")
project(":contracts").projectDir = file("../../../core/contracts")

include(":observation")
project(":observation").projectDir = file("../../../core/observation")
include(":runlog")
project(":runlog").projectDir = file("../../../core/runlog")
include(":agent")
project(":agent").projectDir = file("../../../core/agent")

include(":decision")
project(":decision").projectDir = file("../../../core/decision")

include(":inference")
project(":inference").projectDir = file("../../../core/inference")
include(":bridge")
project(":bridge").projectDir = file("../../../core/bridge")
include(":backend")
project(":backend").projectDir = file("../../../core/backend")

include(":stores")
project(":stores").projectDir = file("../../../apps/android/stores")

