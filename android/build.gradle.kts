allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// shared_preferences currently brings in AppCompat 1.1.0 transitively through
// androidx.preference. That 2019 artifact fails AGP 9's release-resource
// verification, even though the app itself does not use AppCompat widgets.
// Resolve the complete AppCompat pair to the current stable AndroidX release
// for every Flutter plugin module as well as the application module.
subprojects {
    configurations.configureEach {
        resolutionStrategy.force(
            "androidx.appcompat:appcompat:1.8.0",
            "androidx.appcompat:appcompat-resources:1.8.0",
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
