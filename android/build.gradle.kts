allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val configuredBuildRoot = System.getenv("PERSONAL_WORKBENCH_BUILD_ROOT")
val newBuildDir: Directory =
    if (configuredBuildRoot.isNullOrBlank()) {
        rootProject.layout.buildDirectory
            .dir("../../build")
            .get()
    } else {
        rootProject.objects.directoryProperty()
            .fileValue(java.io.File(configuredBuildRoot))
            .get()
    }
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
