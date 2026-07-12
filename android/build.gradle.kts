allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all subprojects (including plugins like flutter_timezone) to
// compile Kotlin to JVM 17, matching the app's compileOptions.
//
// Kotlin and Java compile tasks must agree on the same JVM target or
// Gradle fails with "Inconsistent JVM Target Compatibility Between Java
// and Kotlin Tasks". Plugin modules pulled from pub (e.g. flutter_timezone)
// ship their own build.gradle that may not set Java compatibility to 17,
// so both task types are forced here — forcing only Kotlin (as before)
// left Java at the plugin's own default (11) while Kotlin was bumped to
// 17, which is what caused the mismatch.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
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