plugins {
    id("hopa.kotlin-jvm")
    alias(libs.plugins.kotlin.serialization)
    application
}

application {
    mainClass.set("com.hopa.sidecar.MainKt")
}

dependencies {
    implementation(project(":agent"))
    implementation(project(":observation"))
    implementation(project(":runlog"))
    implementation(project(":catalog"))
    implementation(project(":inference"))
    implementation(project(":bridge"))
    implementation(project(":contracts"))
    implementation(project(":backend"))
    implementation(project(":stores"))

    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.zxing.core)

    testImplementation(libs.junit)
    testImplementation(libs.mockwebserver)
    testImplementation(libs.kotlinx.coroutines.test)
}
