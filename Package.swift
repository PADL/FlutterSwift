// swift-tools-version:5.9

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

#if os(iOS) || os(macOS)
let FlutterRoot = "/opt/flutter"
let FlutterPlatform: String
let FlutterFramework: String
#if os(iOS)
FlutterPlatform = "ios"
FlutterFramework = "Flutter"
#elseif os(macOS)
FlutterPlatform = "darwin-x64"
FlutterFramework = "FlutterMacOS"
#endif
let FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine/\(FlutterPlatform)"
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

#if os(Linux)
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
    name: "CWaylandCursor",
    pkgConfig: "wayland-cursor",
    providers: [.apt(["libwayland-dev", "wayland-protocols"])]
  ),
  .systemLibrary(
    name: "CWaylandEGL",
    pkgConfig: "wayland-egl",
    providers: [.apt(["libwayland-dev", "wayland-protocols"])]
  ),
  .systemLibrary(
    name: "CXKBCommon",
    pkgConfig: "xkbcommon",
    providers: [.apt(["libxkbcommon-dev"])]
  ),
  .target(
    name: "CxxFlutterSwift",
    dependencies: [
      "CEGL",
      "CWaylandCursor",
      "CWaylandEGL",
      "CXKBCommon",
    ],
    exclude: [
      "flutter-embedded-linux/cmake",
      "flutter-embedded-linux/examples",
      "flutter-embedded-linux/src/client_wrapper",
      "flutter-embedded-linux/src/flutter/shell/platform/common/client_wrapper/engine_method_result.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/surface/context_egl_stream.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_drm.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/elinux_window_x11.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_drm_eglstream.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_drm_gbm.cc",
      "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/window/native_window_x11.cc",
    ],
    cSettings: [
    ],
    cxxSettings: [
      .define("DISPLAY_BACKEND_TYPE_WAYLAND"),
      .define("USE_OPENGL_DIRTY_REGION_MANAGEMENT"),
      .define("WL_EGL_PLATFORM"),
      .define("FLUTTER_TARGET_BACKEND_WAYLAND"),
      .define("DISPLAY_BACKEND_TYPE_WAYLAND"),
      .define("RAPIDJSON_HAS_STDSTRING"),
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
      .unsafeFlags(["-I", SwiftLibRoot, "-std=c++17"]),
    ],
    linkerSettings: [
      .unsafeFlags(FlutterUnsafeLinkerFlags),
    ]
  ),
  .executableTarget(
    name: "Counter",
    dependencies: [
      .target(name: "FlutterSwift"),
      "CFlutterEngine",
    ],
    path: "Examples/counter/swift",
    exclude: [
      "README.md",
    ],
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
      .unsafeFlags(FlutterUnsafeLinkerFlags),
    ]
  ),
]

products = [
  .executable(name: "Counter", targets: ["Counter"]),
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
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
    .package(url: "https://github.com/lhoward/AsyncExtensions", branch: "linux"),
  ],
  targets: [
    .target(
      name: "FlutterSwift",
      dependencies: [
        .target(name: "CxxFlutterSwift", condition: .when(platforms: [.linux])),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        "AsyncExtensions",
      ],
      cSettings: [
      ],
      cxxSettings: [
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
      ],
      swiftSettings: [
        .interoperabilityMode(.Cxx),
//                .enableExperimentalFeature("StrictConcurrency")
      ],
      linkerSettings: [
        .unsafeFlags(FlutterUnsafeLinkerFlags),
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
        .unsafeFlags(FlutterUnsafeLinkerFlags),
      ]
    ),
  ] + targets,
  cLanguageStandard: .c17,
  cxxLanguageStandard: .cxx17
)
