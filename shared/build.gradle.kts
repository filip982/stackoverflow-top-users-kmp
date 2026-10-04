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
    // Apple integration path (plan §9.5): direct Gradle embed. Xcode's pre-compile build phase runs
    // `./gradlew :shared:embedAndSignAppleFrameworkForXcode`, which builds this framework for the
    // active CONFIGURATION/SDK into shared/build/xcode-frameworks/; no separate XCFramework step.
    // Slices: device arm64 + simulator arm64 only (Apple Silicon; Intel out of scope).
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "Shared"
            isStatic = true
            // Swift builds the core with `NSUserDefaultsSettings(delegate:)`, so the settings
            // library's API must be in the framework header under unprefixed names.
            export(libs.multiplatform.settings)
            // Belt and braces: the Swift gateway already calls suspend functions on the main
            // thread, but allow any thread so a future caller cannot crash the bridge.
            binaryOption("objcExportSuspendFunctionLaunchThreadRestriction", "none")
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
