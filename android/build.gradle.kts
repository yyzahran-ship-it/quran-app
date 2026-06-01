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
    // Local library modules (e.g. :feature:*) are pure Android libraries that don't
    // use Flutter properties, and :app already depends on them — so excluding them
    // here prevents a circular evaluation-dependency.
    if (!project.path.startsWith(":feature")) {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
