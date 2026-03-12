plugins {
    id("com.android.application")  apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") apply false
    id("com.android.library") apply false
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.2") // latest
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
apply(plugin = "com.google.gms.google-services")
