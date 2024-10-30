// swift-tools-version:5.10

import Foundation
import PackageDescription

func tryGuessSwiftLibRoot() -> String {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/bin/sh")
  task.arguments = ["-c", "which swift"]
  task.standardOutput = Pipe()
  do {
    try task.run()
    let outputData = (task.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
    let path = URL(fileURLWithPath: String(decoding: outputData, as: UTF8.self))
    return path.deletingLastPathComponent().path + "/../lib/swift"
  } catch {
    return "/usr/lib/swift"
  }
}

let SwiftLibRoot = tryGuessSwiftLibRoot()

#if os(macOS) // Note: This is the _build_ platform
let FlutterRoot = "/opt/flutter"
let _FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine"

let FlutterPlatform = "darwin-x64"
let FlutterFramework = "FlutterMacOS"
let FlutterLibPath = "\(_FlutterLibPath)/\(FlutterPlatform)"
let FlutterUnsafeLinkerFlags = [
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
// FIXME: for release target
let FlutterLibPath = "\(FlutterRoot)/elinux-\(FlutterArch)-debug"
let FlutterAltLibPath = "/opt/flutter-elinux/lib"
let FlutterUnsafeLinkerFlags: [String] = [
  "-Xlinker", "-L", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
  "-Xlinker", "-L", "-Xlinker", FlutterAltLibPath,
  "-Xlinker", "-rpath", "-Xlinker", FlutterAltLibPath,
  "-Xlinker", "-l", "-Xlinker", "flutter_engine",
]
#endif

var targets: [Target] = []
var products: [Product] = []

var platformCxxSettings: [CXXSetting] = []
var platformSwiftSettings: [SwiftSetting] = []

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

let FlutterELinuxBackend = FlutterELinuxBackendType.defaultBackend

targets = [
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
      name: "CLibUV",
      pkgConfig: "libuv",
      providers: [.apt(["libuv1-dev"])]
    ),
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
  BackendDependencies = ["CLibUV", "CLibInput", "CLibDRM", "CLibUDev", "CGBM"]
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
    dependencies: ["CEGL", "CXKBCommon"] + BackendDependencies,
    exclude: Exclusions,
    cSettings: [],
    cxxSettings: [
      .define(FlutterELinuxBackend.targetSpecificDefine),
      .define("DISPLAY_BACKEND_TYPE_\(FlutterELinuxBackend.displayBackendType)"),
      .define("FLUTTER_TARGET_BACKEND_\(FlutterELinuxBackend.flutterTargetBackend)"),
      // USE_DIRTY_REGION_MANAGEMENT OFF
      // .define("USE_GLES3"),
      .define("ENABLE_EGL_ALPHA_COMPONENT_OF_COLOR_BUFFER"),
      // ENABLE_VSYNC OFF
      // .define("ENABLE_VSYNC"),
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
      .unsafeFlags(["-pthread", "-I", SwiftLibRoot, "-I", "/usr/include/drm", "-std=c++17"]),
    ],
    linkerSettings: [
      // .unsafeFlags(["-pthread"]),
    ]
  ),
  .executableTarget(
    name: "Counter",
    dependencies: [
      .target(name: "FlutterSwift"),
      "CFlutterEngine",
    ],
    path: "Examples/counter/swift",
    cSettings: [
    ],
    cxxSettings: [
    ],
    swiftSettings: [
      .interoperabilityMode(.Cxx),
      // FIXME: https://github.com/apple/swift-package-manager/issues/6661
      .unsafeFlags(["-cxx-interoperability-mode=default"]),
    ],
    linkerSettings: [
      // .unsafeFlags(["-pthread"]),
    ]
  ),
]

products = [
  .executable(name: "Counter", targets: ["Counter"]),
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
]

platformSwiftSettings += [
  .define("DISPLAY_BACKEND_TYPE_\(FlutterELinuxBackend.displayBackendType)"),
  .define("FLUTTER_TARGET_BACKEND_\(FlutterELinuxBackend.flutterTargetBackend)"),
]
#else

targets = [
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
    .macOS(.v10_15),
    .iOS(.v16),
  ],
  products: [
    .library(name: "FlutterSwift", targets: ["FlutterSwift"]),
  ] + products,
  dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/lhoward/AsyncExtensions", branch: "linux"),
  ],
  targets: [
    .target(
      name: "FlutterSwift",
      dependencies: [
        .target(name: "CxxFlutterSwift", condition: .when(platforms: [.linux])),
        .target(name: "Flutter", condition: .when(platforms: [.iOS])),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        "AsyncExtensions",
      ],
      cSettings: [
      ],
      cxxSettings: platformCxxSettings,
      swiftSettings: platformSwiftSettings + [
        .interoperabilityMode(.Cxx),
      ],
      linkerSettings: [
        .unsafeFlags(FlutterUnsafeLinkerFlags, .when(platforms: [.macOS, .linux])),
      ]
    ),
    .testTarget(
      name: "FlutterSwiftTests",
      dependencies: [
        .target(name: "FlutterSwift"),
      ],
      cSettings: [
      ],
      cxxSettings: [
      ],
      swiftSettings: [
        // FIXME: https://github.com/apple/swift-package-manager/issues/6661
        .interoperabilityMode(.Cxx),
        .unsafeFlags(["-cxx-interoperability-mode=default"]),
      ],
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
