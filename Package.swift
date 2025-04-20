// swift-tools-version:6.0

import Foundation
import PackageDescription

var targets: [Target] = []
var products: [Product] = []

var packageDependencies = [Package.Dependency]()
var targetDependencies = [Target.Dependency]()
var targetPluginUsages = [Target.PluginUsage]()

var platformCxxSettings: [CXXSetting] = []
var platformSwiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

func tryGuessSwiftRoot() -> String {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/bin/sh")
  task.arguments = ["-c", "which swift"]
  task.standardOutput = Pipe()
  do {
    try task.run()
    let outputData = (task.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
    let path = URL(fileURLWithPath: String(decoding: outputData, as: UTF8.self))
    return path.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .path
  } catch {
    return ""
  }
}

let SwiftRoot = tryGuessSwiftRoot()
var FlutterPlatform: String
var FlutterUnsafeLinkerFlags: [String] = []

#if os(macOS) // Note: This is the _build_ platform
let FlutterRoot = "/opt/flutter"
let _FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine"

FlutterPlatform = "darwin-x64"
let FlutterFramework = "FlutterMacOS"
let FlutterLibPath = "\(_FlutterLibPath)/\(FlutterPlatform)"
FlutterUnsafeLinkerFlags = [
  "-Xlinker", "-F", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-framework", "-Xlinker", FlutterFramework,
]
#elseif os(Linux)
// FIXME: this is clearly not right
let FlutterRoot = ".build/artifacts/flutterswift/CFlutterEngine/flutter-engine.artifactbundle"
#if arch(arm64)
let FlutterArch = "arm64"
#elseif arch(x86_64)
let FlutterArch = "x64"
#else
#error("Unknown architecture")
#endif
FlutterPlatform = "elinux-\(FlutterArch)-debug"
// FIXME: for release target
let FlutterLibPath = "\(FlutterRoot)/\(FlutterPlatform)"
let FlutterAltLibPath = "/opt/flutter-elinux/lib"
FlutterUnsafeLinkerFlags = [
  "-Xlinker", "-L", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-L", "-Xlinker", FlutterAltLibPath,
  "-Xlinker", "-rpath", "-Xlinker", FlutterAltLibPath,
  "-Xlinker", "-l", "-Xlinker", "flutter_engine",
]
#endif

let FlutterSwiftJVM: Bool
let javaHome: String?
let javaIncludePath: String?
let javaPlatformIncludePath: String?

if let value = ProcessInfo.processInfo.environment["FLUTTER_SWIFT_JVM"] {
  FlutterSwiftJVM = Bool(value) ?? false
} else {
  FlutterSwiftJVM = false
}

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

if FlutterSwiftJVM {
  javaHome = findJavaHome()

  javaIncludePath = ProcessInfo.processInfo
    .environment["JAVA_INCLUDE_PATH"] ?? "\(javaHome!)/include"
  #if os(Linux)
  javaPlatformIncludePath = "\(javaIncludePath!)/linux"
  #elseif os(macOS)
  javaPlatformIncludePath = "\(javaIncludePath!)/darwin"
  #else
  javaPlatformIncludePath = nil
  #endif

  // TODO: better distinguish between build and target host, support armv7
  FlutterPlatform = "android-arm64"
  FlutterUnsafeLinkerFlags = []

  platformSwiftSettings += [
    .unsafeFlags([
      "-I\(javaIncludePath!)",
      "-I\(javaPlatformIncludePath!)",
    ]),
  ]
  packageDependencies += [
    .package(
      url: "https://github.com/PADL/swift-java",
      branch: "lhoward/android"
    ),
    .package(
      url: "https://github.com/PADL/AndroidLooper",
      from: "0.0.1"
    ),
    .package(
      url: "https://github.com/PADL/AndroidLogging",
      from: "0.0.1"
    ),
  ]
  targetPluginUsages += [
    .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
    .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
  ]

  let javaKitDependencies: [Target.Dependency] = [
    .product(name: "JavaKit", package: "swift-java"),
    .product(name: "JavaKitFunction", package: "swift-java"),
    .product(name: "JavaKitJar", package: "swift-java"),
  ]

  products += [
    .library(
      name: "counter",
      type: .dynamic,
      targets: ["counter"]
    ),
  ]

  targets += [
    .target(
      name: "FlutterAndroid",
      dependencies: javaKitDependencies + [
        "AndroidLooper",
        "AndroidLogging",
        .product(name: "Atomics", package: "swift-atomics"),
      ],
      swiftSettings: platformSwiftSettings,
      plugins: targetPluginUsages
    ),
    .target(
      name: "counter",
      dependencies: [
        .target(name: "FlutterSwift"),
        "AndroidLogging",
        .product(name: "Logging", package: "swift-log"),
      ],
      path: "Examples/counter/swift",
      swiftSettings: platformSwiftSettings,
      plugins: targetPluginUsages
    ),
  ]

  targetDependencies += javaKitDependencies + ["FlutterAndroid"]
} else {
  javaHome = nil
  javaPlatformIncludePath = nil
}

#if os(Linux)
enum FlutterELinuxBackendType {
  static var defaultBackend: FlutterELinuxBackendType {
    if let backend = ProcessInfo.processInfo.environment["FLUTTER_SWIFT_BACKEND"] {
      switch backend {
      case "gbm": return .drmGbm
      case "eglstream": return .drmEglStream
      case "wayland": return .wayland
      default: break
      }
    }
    return .drmGbm
  }

  case drmGbm
  case drmEglStream
  case wayland

  var displayBackendType: String {
    switch self {
    case .drmGbm: return "DRM_GBM"
    case .drmEglStream: return "DRM_EGLSTREAM"
    case .wayland: return "WAYLAND"
    }
  }

  var flutterTargetBackend: String {
    switch self {
    case .drmGbm: return "GBM"
    case .drmEglStream: return "EGLSTREAM"
    case .wayland: return "WAYLAND"
    }
  }

  var targetSpecificDefine: String {
    switch self {
    case .drmGbm: return "__GBM__"
    case .drmEglStream: return "EGL_NO_X11"
    case .wayland: return "WL_EGL_PLATFORM"
    }
  }
}

packageDependencies += [
  .package(url: "https://github.com/xtremekforever/swift-systemd", branch: "main"),
]

let FlutterELinuxBackend = FlutterELinuxBackendType.defaultBackend

let CxxIncludeDirs: [String] = [
  "\(SwiftRoot)/usr/include",
  "\(SwiftRoot)/usr/lib/swift",
  "/usr/include/drm",
]

let CxxIncludeFlags = CxxIncludeDirs.flatMap { ["-I", $0] }

platformSwiftSettings += [
  .define("DISPLAY_BACKEND_TYPE_\(FlutterELinuxBackend.displayBackendType)"),
  .define("FLUTTER_TARGET_BACKEND_\(FlutterELinuxBackend.flutterTargetBackend)"),
  .interoperabilityMode(.Cxx),
  .unsafeFlags(CxxIncludeFlags),
]

targets += [
  .binaryTarget(
    name: "CFlutterEngine",
    path: "flutter-engine.artifactbundle.zip"
  ),
  .systemLibrary(
    name: "CEGL",
    pkgConfig: "egl",
    providers: [.apt(["libegl1-mesa-dev", "libgles2-mesa-dev"])]
  ),
  .systemLibrary(
    name: "CXKBCommon",
    pkgConfig: "xkbcommon",
    providers: [.apt(["libxkbcommon-dev"])]
  ),
]

switch FlutterELinuxBackend {
case .drmGbm:
  targets += [
    .systemLibrary(
      name: "CLibInput",
      pkgConfig: "libinput",
      providers: [.apt(["libinput-dev"])]
    ),
    .systemLibrary(
      name: "CLibDRM",
      pkgConfig: "libdrm",
      providers: [.apt(["libdrm-dev"])]
    ),
    .systemLibrary(
      name: "CLibUDev",
      pkgConfig: "libudev",
      providers: [.apt(["libudev-dev"])]
    ),
    .systemLibrary(
      name: "CGBM",
      pkgConfig: "gbm",
      providers: [.apt(["libgbm-dev"])]
    ),
  ]
case .drmEglStream:
  break // TODO:
case .wayland:
  targets += [
    .systemLibrary(
      name: "CWaylandCursor",
      pkgConfig: "wayland-cursor",
      providers: [.apt(["libwayland-dev", "wayland-protocols"])]
    ),
    .systemLibrary(
      name: "CWaylandEGL",
      pkgConfig: "wayland-egl",
      providers: [.apt(["libwayland-dev", "wayland-protocols"])]
    ),
  ]
}

let WaylandSources = [
  "elinux_window_wayland.cc",
  "native_window_wayland.cc",
  "native_window_wayland_decoration.cc",
]
let DRMCommonSources = [
  "native_window_drm.cc",
]
let DRMGBMSources = [
  "native_window_drm_gbm.cc",
]
let DRMEGLSources = [
  "native_window_drm_eglstream.cc",
]

let X11Sources = ["elinux_window_x11.cc", "native_window_x11.cc"]

let ExcludedSources: [String]
let BackendDependencies: [Target.Dependency]

switch FlutterELinuxBackend {
case .drmGbm:
  BackendDependencies = ["CLibInput", "CLibDRM", "CLibUDev", "CGBM"]
  ExcludedSources = WaylandSources + DRMEGLSources
case .drmEglStream:
  BackendDependencies = [] // TODO:
  ExcludedSources = WaylandSources + DRMGBMSources
case .wayland:
  BackendDependencies = ["CWaylandCursor", "CWaylandEGL"]
  ExcludedSources = DRMCommonSources + DRMGBMSources + DRMEGLSources
}

var Exclusions: [String] = [
  "flutter-embedded-linux/cmake",
  "flutter-embedded-linux/examples",
  "flutter-embedded-linux/src/client_wrapper",
  "flutter-embedded-linux/src/flutter/shell/platform/common/client_wrapper/engine_method_result.cc",
]

if FlutterELinuxBackend != .wayland {
  Exclusions += ["wayland",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/elinux_window_wayland.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_wayland.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_wayland_decoration.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/elinux_shader.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/elinux_shader_context.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/elinux_shader_program.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/window_decoration_button.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/window_decoration_titlebar.cc",
                 "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/renderer/window_decorations_wayland.cc"]
}

if FlutterELinuxBackend != .drmEglStream {
  Exclusions +=
    [
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/surface/context_egl_stream.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/surface/environment_egl_stream.cc",
    ]
}

Exclusions += X11Sources
  .map { "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/\($0)" }
Exclusions += ExcludedSources
  .map { "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/\($0)" }

targets += [
  .target(
    name: "CxxFlutterSwift",
    dependencies: [
      "CEGL",
      "CXKBCommon",
      .product(name: "Systemd", package: "swift-systemd", condition: .when(platforms: [.linux])),
    ] + BackendDependencies,
    exclude: Exclusions,
    cSettings: [],
    cxxSettings: [
      .define(FlutterELinuxBackend.targetSpecificDefine),
      .define("DISPLAY_BACKEND_TYPE_\(FlutterELinuxBackend.displayBackendType)"),
      .define("FLUTTER_TARGET_BACKEND_\(FlutterELinuxBackend.flutterTargetBackend)"),
      // USE_DIRTY_REGION_MANAGEMENT OFF
      // .define("USE_GLES3"),
      .define("ENABLE_EGL_ALPHA_COMPONENT_OF_COLOR_BUFFER"),
      .define("ENABLE_VSYNC"),
      .define("USE_LIBSYSTEMD"),
      // ENABLE_ELINUX_EMBEDDER_LOG ON
      .define("ENABLE_ELINUX_EMBEDDER_LOG"),
      // .define("FLUTTER_RELEASE") // FIXME: for release
      .define("RAPIDJSON_HAS_STDSTRING"),
      .define("RAPIDJSON_HAS_CXX11_RANGE_FOR"),
      .define("RAPIDJSON_HAS_CXX11_RVALUE_REFS"),
      .define("RAPIDJSON_HAS_CXX11_TYPETRAITS"),
      .define("RAPIDJSON_HAS_CXX11_NOEXCEPT"),
      .headerSearchPath("."),
      .headerSearchPath("flutter-embedded-linux/src"),
      .headerSearchPath("flutter-embedded-linux/src/flutter/shell/platform/linux_embedded"),
      .headerSearchPath("flutter-embedded-linux/src/flutter/shell/platform/common/public"),
      .headerSearchPath(
        "flutter-embedded-linux/src/flutter/shell/platform/common/client_wrapper/include"
      ),
      .headerSearchPath(
        "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/public"
      ),
      .headerSearchPath("flutter-embedded-linux/src/third_party/rapidjson/include"),
      // FIXME: .cxxLanguageStandard breaks Foundation compile
      // FIXME: include path for swift/bridging.h
      .unsafeFlags(["-pthread", "-std=c++17"] + CxxIncludeFlags),
    ],
    linkerSettings: [
      // .unsafeFlags(["-pthread"]),
    ]
  ),
  .executableTarget(
    name: "counter",
    dependencies: [
      .target(name: "FlutterSwift"),
      .product(name: "Logging", package: "swift-log"),
      "CFlutterEngine",
    ],
    path: "Examples/counter/swift",
    cSettings: [
    ],
    cxxSettings: [
    ],
    swiftSettings: platformSwiftSettings
  ),
]

products = [
  .executable(name: "counter", targets: ["counter"]),
]

platformCxxSettings += [
  .define("DISPLAY_BACKEND_TYPE_\(FlutterELinuxBackend.displayBackendType)"),
  .define("FLUTTER_TARGET_BACKEND_\(FlutterELinuxBackend.flutterTargetBackend)"),
  .headerSearchPath("../CxxFlutterSwift/flutter-embedded-linux/src"),
  .headerSearchPath(
    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/linux_embedded"
  ),
  .headerSearchPath(
    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/public"
  ),
  .headerSearchPath(
    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/common/public"
  ),
  .headerSearchPath(
    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/common/client_wrapper/include"
  ),
  .headerSearchPath("../CxxFlutterSwift/flutter-embedded-linux/src/third_party/rapidjson/include"),
  .unsafeFlags(CxxIncludeFlags),
]

#else

targets += [
  .target(
    name: "CxxFlutterSwift",
    exclude: [
      ".",
      "wayland",
    ]
  ),
]

#endif

let package = Package(
  name: "FlutterSwift",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
  ],
  products: [
    .library(
      name: "FlutterSwift",
      type: .static,
      targets: ["FlutterSwift"]
    ),
  ] + products,
  dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-atomics", from: "1.0.0"),
    .package(url: "https://github.com/lhoward/AsyncExtensions", from: "0.9.0"),
    // TODO: use a release when one made with Android support
    .package(url: "https://github.com/apple/swift-log", from: "1.6.2"),
  ] + packageDependencies,
  targets: [
    .target(
      name: "FlutterSwift",
      dependencies: [
        .target(name: "CxxFlutterSwift", condition: .when(platforms: [.linux])),
        .target(name: "Flutter", condition: .when(platforms: [.iOS])),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "Atomics", package: "swift-atomics"),
        "AsyncExtensions",
      ] + targetDependencies,
      cxxSettings: platformCxxSettings,
      swiftSettings: platformSwiftSettings,
      linkerSettings: [
        .unsafeFlags(FlutterUnsafeLinkerFlags, .when(platforms: [.macOS, .linux])),
      ]
    ),
    .testTarget(
      name: "FlutterSwiftTests",
      dependencies: [
        .target(name: "FlutterSwift"),
      ],
      cxxSettings: platformCxxSettings,
      swiftSettings: platformSwiftSettings,
      linkerSettings: [
        .unsafeFlags(FlutterUnsafeLinkerFlags, .when(platforms: [.macOS, .linux])),
      ]
    ),
    .binaryTarget(
      name: "Flutter",
      path: "Flutter.xcframework.zip"
    ),
  ] + targets,
  cLanguageStandard: .c17,
  cxxLanguageStandard: .cxx17
)
