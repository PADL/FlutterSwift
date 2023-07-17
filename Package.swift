// swift-tools-version:5.9

import Foundation
import PackageDescription

#if os(macOS)
let FlutterRoot = "/opt/flutter"
let FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine/darwin-x64-release"
let FlutterIncludePath = ""
let FlutterBackend = ""
let FlutterUnsafeLinkerFlags = [
    "-Xlinker", "-F", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-framework", "-Xlinker", "FlutterMacOS",
]
#elseif os(Linux)

let FlutterRoot = "/opt/elinux"
let FlutterLibPath = "\(FlutterRoot)/lib"
let FlutterIncludePath = "\(FlutterRoot)/include"
let FlutterBackend = "wayland"
// FIXME: we should download this as a binary artifact or perhaps check it in directly
let FlutterUnsafeLinkerFlags: [String] = [
    "-Xlinker", "-L", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-l", "-Xlinker", "flutter_engine",
]
#endif

var target: [Target] = []

#if os(Linux)
target = [
    .systemLibrary(
        name: "CEGL",
        pkgConfig: "egl"
        // providers: .apt(["libegl1-mesa-dev", "libgles2-mesa-dev"])
    ),
    .systemLibrary(
        name: "CWaylandCursor",
        pkgConfig: "wayland-cursor"
        // providers: .apt(["libwayland-dev", "wayland-protocols"])
    ),
    .systemLibrary(
        name: "CWaylandEGL",
        pkgConfig: "wayland-egl"
        // providers: .apt(["libwayland-dev", "wayland-protocols"])
    ),
    .systemLibrary(
        name: "CXKBCommon",
        pkgConfig: "xkbcommon"
        // providers: .apt(["libxkbcommon-dev"])
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
                "flutter-embedded-linux/src/flutter/shell/platform/common/client_wrapper/include/flutter"
            ),
            .headerSearchPath(
                "flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/public"
            ),
            .headerSearchPath("flutter-embedded-linux/src/third_party/rapidjson/include"),
            // FIXME: .cxxLanguageStandard breaks Foundation compile
            // FIXME: include path for swift/bridging.h
            .unsafeFlags(["-I", "/opt/swift/usr/include", "-std=c++17"]),
        ],
        linkerSettings: [
            .unsafeFlags(FlutterUnsafeLinkerFlags),
        ]
    ),
    .executableTarget(
        name: "Counter",
        dependencies: [
            .target(name: "FlutterSwift"),
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
#endif

let package = Package(
    name: "FlutterSwift",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "FlutterSwift", targets: ["FlutterSwift"]),
        .executable(name: "Counter", targets: ["Counter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.0.0"),
    ],
    targets: [
        .target(
            name: "FlutterSwift",
            dependencies: [
                .target(name: "CxxFlutterSwift", condition: .when(platforms: [.linux])),
                "AnyCodable",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            cSettings: [
            ],
            cxxSettings: [
                .headerSearchPath("../CxxFlutterSwift/flutter-embedded-linux/src"),
                .headerSearchPath("../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/linux_embedded"),
                .headerSearchPath(
                    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/linux_embedded/public"
                ),
                .headerSearchPath(
                    "../CxxFlutterSwift/flutter-embedded-linux/src/flutter/shell/platform/common/public"
                ),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)],
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
    ] + target,
    cLanguageStandard: .c17
    // cxxLanguageStandard: .cxx17
)

#if false
let SonyFlutterEngineBuild =
    "https://github.com/sony/flutter-embedded-linux/releases/download/cdbeda788a"
#if arch(x86_64)
let SonyFlutterEngineArch = "x64"
let SonyFlutterEngineChecksum = "8abd82b8710a32b5181db6f40e453474f7004c62735838567bbd2ee7328ca7fd"
#elseif arch(arm64)
let SonyFlutterEngineArch = "arm64"
let SonyFlutterEngineChecksum = "0fcdb6de88e4a3848250d699ba46a0b691e9628d2243b6eeed7caf8267b7ba4a"
#endif
let SonyFlutterEngineConfig = "debug"
let SonyFlutterEngineURL =
    "\(SonyFlutterEngineBuild)/elinux-\(SonyFlutterEngineArch)-\(SonyFlutterEngineConfig).zip"
#endif
