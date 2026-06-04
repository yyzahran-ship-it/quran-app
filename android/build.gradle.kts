allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Flutter plugin subprojects need app to be evaluated first so they can read
    // flutter.compileSdkVersion / flutter.minSdkVersion from the FlutterExtension.
    project.evaluationDependsOn(":app")
}

// flutter_tts 4.x is incompatible with the K2 compiler (Kotlin 2.0+).
// Force K1 language semantics for all Kotlin plugin subprojects so the build succeeds.
// plugins.withId is safe on already-evaluated projects (unlike afterEvaluate).
subprojects {
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
