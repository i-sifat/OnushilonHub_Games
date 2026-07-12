allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force subprojects' Kotlin compile tasks to a JVM target that matches
// their own Java compile task, avoiding "Inconsistent JVM Target
// Compatibility Between Java and Kotlin Tasks".
//
// We only control this via KotlinCompile.compilerOptions — attempting to
// force JavaCompile.sourceCompatibility/targetCompatibility here does NOT
// reliably stick for Android-library plugin modules, since AGP wires those
// properties from its own `compileOptions` extension after this script
// runs, silently overriding a raw task-property assignment. So instead of
// fighting Java upward, we match Kotlin to whatever each plugin's own Java
// target already is:
//   - flutter_timezone ships with Java 11 — its Kotlin task is pinned to 11.
//   - everything else follows the app's Java 17 (see android/app/build.gradle.kts).
subprojects {
    afterEvaluate {
        val kotlinJvmTarget = if (project.name == "flutter_timezone") {
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        } else {
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(kotlinJvmTarget)
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}