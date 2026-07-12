allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Align every Android subproject's Java AND Kotlin compile tasks to the
// same JVM target (17), avoiding "Inconsistent JVM Target Compatibility
// Between Java and Kotlin Tasks".
//
// The key detail: AGP derives JavaCompile source/targetCompatibility from
// its own `compileOptions` extension, so assigning the raw JavaCompile
// task properties here does NOT stick (AGP overwrites them afterward).
// We therefore configure the AGP extension itself, which is the property
// AGP actually honors, and match Kotlin to it. This is version-agnostic:
// whatever Java level a plugin (e.g. flutter_timezone) ships with, it is
// forced up to 17 to match the app (see android/app/build.gradle.kts).
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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

tasks.register("clean") {
    delete(rootProject.layout.buildDirectory)
}
