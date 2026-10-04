import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinJvm)
    application
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

// Shared fixtures (<root>/fixtures) are packaged under fixtures/ on the classpath.
val copyFixtures by tasks.registering(Sync::class) {
    from(rootProject.layout.projectDirectory.dir("fixtures"))
    into(layout.buildDirectory.dir("generated/fixtureResources/fixtures"))
}
sourceSets.main {
    resources.srcDir(files(layout.buildDirectory.dir("generated/fixtureResources")).builtBy(copyFixtures))
}

application {
    mainClass.set("dev.filip.sotopusers.mockserver.MainKt")
}

dependencies {
    implementation(libs.ktor.server.core)
    implementation(libs.ktor.server.cio)
    implementation(libs.logback.classic)
    testImplementation(kotlin("test"))
    testImplementation(libs.ktor.client.cio)
    testImplementation(libs.kotlinx.coroutines.test)
}

tasks.test {
    useJUnitPlatform()
}
