// swift-android.gradle.kts
// Gradle integration for building FlutterSwift Android libraries
//
// This script cross-compiles the Swift `counter` product (which depends on
// FlutterSwift and FlutterAndroid) for Android, packages the Java bridge
// classes into flutterswift.jar, and copies the native libraries into the
// APK via jniLibs.

import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Exec
import org.gradle.api.file.DuplicatesStrategy

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

data class SwiftConfig(
    var apiLevel: Int = 28,
    var debugAbiFilters: Set<String> = setOf("arm64-v8a"),
    var releaseAbiFilters: Set<String> = setOf("arm64-v8a"),
    var swiftlyPath: String? = null,
    var swiftSDKPath: String? = null,
    var swiftVersion: String = "6.3",
    var androidSdkVersion: String = "6.3-RELEASE_android",
    var swiftProduct: String = "counter",
)

data class Arch(
    val androidAbi: String,
    val triple: String,
    val swiftArch: String,
    val swiftTarget: String,
    val variantName: String
)

val architectures = mapOf(
    "arm64" to Arch(
        androidAbi = "arm64-v8a",
        triple = "aarch64-linux-android",
        swiftArch = "aarch64",
        swiftTarget = "aarch64-unknown-linux-android",
        variantName = "Arm64"
    ),
    "x86_64" to Arch(
        androidAbi = "x86_64",
        triple = "x86_64-linux-android",
        swiftArch = "x86_64",
        swiftTarget = "x86_64-unknown-linux-android",
        variantName = "X86_64"
    ),
)

val swiftConfig = (project.extensions.findByName("swiftConfig") as? SwiftConfig)
    ?: SwiftConfig().also {
        project.extensions.add("swiftConfig", it)
    }

// The FlutterSwift repo root (where Package.swift lives)
val flutterSwiftRoot = project.file("../../../..")

// Read flutter.sdk from local.properties
fun getFlutterSdkPath(): String {
    val localProps = java.util.Properties()
    val localPropsFile = project.rootProject.file("local.properties")
    if (localPropsFile.exists()) {
        localPropsFile.inputStream().use { localProps.load(it) }
    }
    return localProps.getProperty("flutter.sdk") ?: "/opt/flutter"
}

fun getSwiftlyPath(): String {
    swiftConfig.swiftlyPath?.let { return it }

    val homeDir = System.getProperty("user.home")
    val possiblePaths = listOf(
        "$homeDir/.swiftly/bin/swiftly",
        "$homeDir/.local/share/swiftly/bin/swiftly",
        "$homeDir/.local/bin/swiftly",
        "/usr/local/bin/swiftly",
        "/opt/homebrew/bin/swiftly",
    )
    for (path in possiblePaths) {
        if (file(path).exists()) {
            return path
        }
    }
    throw GradleException("swiftly not found. Please set swiftConfig.swiftlyPath or install swiftly.")
}

fun getSwiftSDKPath(): String {
    swiftConfig.swiftSDKPath?.let { return it }

    val homeDir = System.getProperty("user.home")
    val possiblePaths = listOf(
        "$homeDir/Library/org.swift.swiftpm/swift-sdks/",
        "$homeDir/.config/swiftpm/swift-sdks/",
        "$homeDir/.swiftpm/swift-sdks/",
    )
    for (path in possiblePaths) {
        if (file(path).exists()) {
            return path
        }
    }
    throw GradleException("Swift SDK path not found. Please set swiftConfig.swiftSDKPath or install the Swift SDK for Android.")
}

fun getSwiftResourcesPath(arch: Arch): String {
    val sdkVersion = swiftConfig.androidSdkVersion
    return "${getSwiftSDKPath()}/swift-${sdkVersion}.artifactbundle/swift-android/swift-resources/usr/lib/swift_static-${arch.swiftArch}/"
}

// ---------------------------------------------------------------------------
// Task factories
// ---------------------------------------------------------------------------

// Task: Write the flutter.jar classpath file so SwiftJavaPlugin can find Flutter classes
fun createWriteClasspathTask(
    buildTypeName: String,
    arch: Arch,
    isDebug: Boolean
): TaskProvider<Exec> {
    val taskName = "swiftWriteClasspath${arch.variantName}${buildTypeName.replaceFirstChar { it.uppercaseChar() }}"

    return tasks.findByName(taskName)?.let {
        tasks.named<Exec>(taskName)
    } ?: tasks.register<Exec>(taskName) {
        val flutterSdk = getFlutterSdkPath()
        val flutterClasspath = "$flutterSdk/bin/cache/artifacts/engine/android-arm64/flutter.jar"
        val classpathDir = File(flutterSwiftRoot, ".build/plugins/outputs/flutterswift/FlutterAndroid/destination/SwiftJavaPlugin")
        val classpathFile = File(classpathDir, "Flutter.swift-java.classpath")

        workingDir(flutterSwiftRoot)
        commandLine("sh", "-c", "mkdir -p '${classpathDir}' && printf '%s' '${flutterClasspath}' > '${classpathFile}'")

        doFirst {
            println("Writing Flutter classpath: $flutterClasspath")
        }
    }
}

// Task: Cross-compile Swift for Android
fun createSwiftBuildTask(
    buildTypeName: String,
    arch: Arch,
    isDebug: Boolean,
    writeClasspathTask: TaskProvider<Exec>
): TaskProvider<Exec> {
    val taskName = "swiftBuild${arch.variantName}${buildTypeName.replaceFirstChar { it.uppercaseChar() }}"

    return tasks.findByName(taskName)?.let {
        tasks.named<Exec>(taskName)
    } ?: tasks.register<Exec>(taskName) {
        val swiftlyPath = getSwiftlyPath()
        val resourcesPath = getSwiftResourcesPath(arch)
        val swiftVersion = swiftConfig.swiftVersion
        val flutterSdk = getFlutterSdkPath()
        val flutterClasspath = "$flutterSdk/bin/cache/artifacts/engine/android-arm64/flutter.jar"
        val sdkName = "${arch.swiftTarget}${swiftConfig.apiLevel}"

        dependsOn(writeClasspathTask)

        workingDir(flutterSwiftRoot)
        executable(swiftlyPath)
        args(listOf(
            "run", "+${swiftVersion}", "swift", "build",
            "--swift-sdk", sdkName,
            "-c", if (isDebug) "debug" else "release",
            "--product", swiftConfig.swiftProduct
        ))

        environment("FLUTTER_SWIFT_JVM", "true")
        environment("CLASSPATH", flutterClasspath)
        // JAVA_HOME is needed by Package.swift's findJavaHome() when FLUTTER_SWIFT_JVM=true.
        // Point it at Android Studio's bundled JBR (or any JDK with include/jni.h).
        val javaHome = System.getenv("JAVA_HOME")
            ?: "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        environment("JAVA_HOME", javaHome)

        doFirst {
            println("Building Swift product '${swiftConfig.swiftProduct}' for ${arch.variantName} ${if (isDebug) "Debug" else "Release"}")
            println("Swift SDK: $sdkName")
            println("Working dir: $flutterSwiftRoot")
        }
    }
}

// Task: Package FlutterAndroid Java classes into flutterswift.jar
fun createPackageJarTask(
    buildTypeName: String,
    arch: Arch,
    isDebug: Boolean,
    swiftBuildTask: TaskProvider<Exec>
): TaskProvider<Exec> {
    val taskName = "packageSwiftJar${arch.variantName}${buildTypeName.replaceFirstChar { it.uppercaseChar() }}"

    return tasks.findByName(taskName)?.let {
        tasks.named<Exec>(taskName)
    } ?: tasks.register<Exec>(taskName) {
        val pluginsRoot = File(flutterSwiftRoot, ".build/plugins/outputs/flutterswift")
        val javaClassesDir = File(pluginsRoot, "FlutterAndroid/destination/JavaCompilerPlugin/Java")
        val jarOutput = project.file("libs/flutterswift.jar")

        dependsOn(swiftBuildTask)

        workingDir(javaClassesDir)
        commandLine("jar", "cf", jarOutput.absolutePath, ".")

        doFirst {
            jarOutput.parentFile.mkdirs()
            println("Packaging flutterswift.jar from $javaClassesDir")
        }
    }
}

// Task: Copy Swift .so libraries into jniLibs
fun createCopySwiftLibrariesTask(
    buildTypeName: String,
    arch: Arch,
    isDebug: Boolean,
    swiftBuildTask: TaskProvider<Exec>,
    packageJarTask: TaskProvider<Exec>
): TaskProvider<Copy> {
    val taskName = "copySwift${arch.variantName}${buildTypeName.replaceFirstChar { it.uppercaseChar() }}"

    return tasks.findByName(taskName)?.let {
        tasks.named<Copy>(taskName)
    } ?: tasks.register<Copy>(taskName) {
        val swiftPmBuildPath = if (isDebug) {
            "${flutterSwiftRoot}/.build/${arch.swiftTarget}${swiftConfig.apiLevel}/debug"
        } else {
            "${flutterSwiftRoot}/.build/${arch.swiftTarget}${swiftConfig.apiLevel}/release"
        }

        dependsOn(swiftBuildTask)
        dependsOn(packageJarTask)

        // Copy all built .so files (product + dynamic dependencies like libSwiftJava.so)
        from(fileTree(swiftPmBuildPath) {
            include("*.so")
        })

        // Copy Swift runtime .so files from the SDK swift-resources directory
        val swiftResourcesPath = "${getSwiftSDKPath()}/swift-${swiftConfig.androidSdkVersion}.artifactbundle/swift-android/swift-resources/usr/lib/swift-${arch.swiftArch}/android"
        from(fileTree(swiftResourcesPath) {
            include("*.so")
        })

        // Copy libc++_shared.so from the SDK sysroot
        from("${getSwiftSDKPath()}/swift-${swiftConfig.androidSdkVersion}.artifactbundle/swift-android/ndk-sysroot/usr/lib/${arch.triple}") {
            include("libc++_shared.so")
        }

        if (isDebug) {
            into("src/debug/jniLibs/${arch.androidAbi}")
        } else {
            into("src/release/jniLibs/${arch.androidAbi}")
        }

        filePermissions {
            unix("0644".toInt(8))
        }
        duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
}

// ---------------------------------------------------------------------------
// Wire tasks into Android build pipeline
// ---------------------------------------------------------------------------

fun handleVariant(variant: Any) {
    val variantClass = variant::class.java

    val buildTypeMethod = variantClass.getMethod("getBuildType")
    val buildType = buildTypeMethod.invoke(variant)
    val buildTypeClass = buildType::class.java

    val isJniDebuggableMethod = buildTypeClass.getMethod("isJniDebuggable")
    val isDebug = isJniDebuggableMethod.invoke(buildType) as Boolean

    val getNameMethod = variantClass.getMethod("getName")
    val variantName = getNameMethod.invoke(variant) as String

    val getBuildTypeNameMethod = buildTypeClass.getMethod("getName")
    val buildTypeName = getBuildTypeNameMethod.invoke(buildType) as String

    val abiFilters = if (isDebug) {
        swiftConfig.debugAbiFilters
    } else {
        swiftConfig.releaseAbiFilters
    }

    architectures.values.forEach { arch ->
        if (abiFilters.isEmpty() || abiFilters.contains(arch.androidAbi)) {
            val writeClasspathTask = createWriteClasspathTask(buildTypeName, arch, isDebug)
            val swiftBuildTask = createSwiftBuildTask(buildTypeName, arch, isDebug, writeClasspathTask)
            val packageJarTask = createPackageJarTask(buildTypeName, arch, isDebug, swiftBuildTask)
            val copyTask = createCopySwiftLibrariesTask(buildTypeName, arch, isDebug, swiftBuildTask, packageJarTask)

            val capitalizedVariantName = variantName.replaceFirstChar { it.uppercaseChar() }
            tasks.findByName("merge${capitalizedVariantName}JniLibFolders")?.let { task ->
                task.dependsOn(copyTask)
            }
        }
    }
}

project.afterEvaluate {
    val androidExtension = project.extensions.findByName("android")
    if (androidExtension != null) {
        try {
            val applicationVariantsMethod = androidExtension::class.java.getMethod("getApplicationVariants")
            val variants = applicationVariantsMethod.invoke(androidExtension)
            val allMethod = variants::class.java.getMethod("all", groovy.lang.Closure::class.java)

            allMethod.invoke(variants, object : groovy.lang.Closure<Unit>(this) {
                fun doCall(variant: Any) {
                    handleVariant(variant)
                }
            })
        } catch (e: NoSuchMethodException) {
            // Not an application module
        }
    } else {
        throw GradleException("Android extension not found. Apply this script after the Android plugin.")
    }
}
