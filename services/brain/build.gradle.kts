plugins {
    kotlin("jvm") version "2.4.21"
}

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17)
}

// The checks below are `main` functions, so the JUnit task discovers nothing.
// Gradle 9 fails an empty test task by default; the brainChecks are the gate.
tasks.withType<Test>().configureEach {
    failOnNoDiscoveredTests = false
}

dependencies {
    implementation("com.google.code.gson:gson:2.11.0")
}

/**
 * The brain's checks are `main` functions, not JUnit classes: they throw
 * `AssertionError` on the first failure and exit non-zero. Each one becomes a
 * JavaExec so `check` runs the same assertions the standalone compiler ran,
 * without a second Kotlin compiler.
 */
fun brainCheck(name: String, main: String, vararg args: String) =
    tasks.register<JavaExec>("brainCheck$name") {
        group = "verification"
        description = "Runs the $name brain checks."
        dependsOn(tasks.named("testClasses"))
        classpath = sourceSets["test"].runtimeClasspath
        mainClass.set(main)
        workingDir = projectDir
        this.args = args.map { project.file(it).absolutePath }
    }

val brainChecks = listOf(
    brainCheck("Router", "hopa.brain.routing.RouterTestKt"),
    brainCheck("Server", "hopa.brain.http.ServerTestKt"),
    brainCheck("Knowledge", "hopa.brain.knowledge.KnowledgeLoaderTestKt", "knowledge/apps"),
    brainCheck("Prompts", "hopa.brain.prompts.PromptBookTestKt"),
    brainCheck("Skills", "hopa.brain.knowledge.SkillLoaderTestKt", "knowledge/skills"),
    brainCheck("Sites", "hopa.brain.knowledge.SiteLoaderTestKt", "knowledge/sites"),
)

tasks.named("check") {
    dependsOn(brainChecks)
    // The cross-language contract starts build/brain.jar; build it with check.
    dependsOn("fatJar")
}

/**
 * One self-contained jar, so `java -cp services/brain/build/brain.jar
 * hopa.brain.http.ServerKt` keeps working. The standalone compiler used to
 * bundle the stdlib with `-include-runtime`; this does the same through Gradle.
 */
tasks.register<Jar>("fatJar") {
    group = "build"
    description = "Builds the runnable brain.jar with the Kotlin stdlib and Gson."
    archiveFileName.set("brain.jar")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    manifest {
        attributes["Main-Class"] = "hopa.brain.http.ServerKt"
    }
    from(sourceSets.main.get().output)
    dependsOn(configurations.runtimeClasspath)
    from({
        configurations.runtimeClasspath.get()
            .filter { it.name.endsWith(".jar") }
            .map { zipTree(it) }
    })
}
