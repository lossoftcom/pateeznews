pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

val builtInKotlinPluginBuildFiles =
    mapOf(
        "file_selector_android" to "flutter_plugin_build_shims/file_selector_android.gradle.kts",
        "pro_image_editor" to "flutter_plugin_build_shims/pro_image_editor.gradle",
        "quill_native_bridge_android" to "flutter_plugin_build_shims/quill_native_bridge_android.gradle",
        "shared_preferences_android" to "flutter_plugin_build_shims/shared_preferences_android.gradle.kts",
        "url_launcher_android" to "flutter_plugin_build_shims/url_launcher_android.gradle.kts",
        "webview_flutter_android" to "flutter_plugin_build_shims/webview_flutter_android.gradle.kts",
    )

builtInKotlinPluginBuildFiles.forEach { (pluginName, buildFilePath) ->
    val pluginProject = findProject(":$pluginName") ?: return@forEach
    pluginProject.buildFileName =
        pluginProject.projectDir
            .toPath()
            .relativize(file(buildFilePath).toPath())
            .toString()
}

include(":app")
