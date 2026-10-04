import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.kotlinSerialization)
    alias(libs.plugins.androidLibrary)
}

// Fixtures live in <root>/fixtures and are the single source of truth for every test level.
// The mockserver serves them as classpath resources; commonTest gets them as generated Kotlin
// constants (common code has no portable resource loading).
val fixturesDir = rootProject.layout.projectDirectory.dir("fixtures")
val generatedFixturesDir = layout.buildDirectory.dir("generated/fixtures/commonTest/kotlin")

val generateFixtureSources by tasks.registering {
    val inputDir = fixturesDir
    val outputDir = generatedFixturesDir
    inputs.dir(inputDir)
    outputs.dir(outputDir)
    doLast {
        val files = inputDir.asFile.listFiles { f -> f.extension == "json" }!!.sortedBy { it.name }
        val body = buildString {
            appendLine("// GENERATED from /fixtures by :shared:generateFixtureSources. Do not edit.")
            appendLine("package dev.filip.sotopusers.fixtures")
            appendLine()
            appendLine("object Fixtures {")
            for (f in files) {
                val name = f.nameWithoutExtension.split('_')
                    .mapIndexed { i, s -> if (i == 0) s else s.replaceFirstChar(Char::uppercase) }
                    .joinToString("")
                val text = f.readText().replace("$", "\${'$'}")
                appendLine("    val $name: String = \"\"\"$text\"\"\"")
                appendLine()
            }
            appendLine("}")
        }
        val out = outputDir.get().file("dev/filip/sotopusers/fixtures/Fixtures.kt").asFile
        out.parentFile.mkdirs()
        out.writeText(body)
    }
}

kotlin {
    androidTarget {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }
    jvm {
        compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
    }
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.ktor.client.core)
            api(libs.multiplatform.settings)
        }
        commonTest {
            kotlin.srcDir(generateFixtureSources)
            dependencies {
                implementation(kotlin("test"))
                implementation(libs.kotlinx.coroutines.test)
                implementation(libs.ktor.client.mock)
                implementation(libs.multiplatform.settings.test)
                implementation(libs.turbine)
            }
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
        }
        jvmMain.dependencies {
            implementation(libs.ktor.client.cio)
            implementation(libs.ktor.client.encoding)
        }
        jvmTest.dependencies {
            implementation(project(":mockserver"))
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }
    }
}

android {
    namespace = "dev.filip.sotopusers.shared"
    compileSdk = libs.versions.android.compileSdk.get().toInt()
    defaultConfig {
        minSdk = libs.versions.android.minSdk.get().toInt()
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
