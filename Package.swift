// swift-tools-version:5.9

import Foundation
import PackageDescription

#if os(macOS)
let FlutterRoot = "/opt/flutter"
let FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine/darwin-x64-release"
let FlutterIncludePath = ""
let FlutterBackend = ""
let FlutterUnsafeCxxCompilerFlags = [String]()
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
let FlutterUnsafeCxxCompilerFlags = [
    "-I", FlutterIncludePath,
    // FIXME: we should find this automatically
//    "-I", "/opt/swift/usr/lib/swift",
]
let FlutterUnsafeLinkerFlags = [
    "-Xlinker", "-L", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-l", "-Xlinker", "flutter_engine",
    "-Xlinker", "-l", "-Xlinker", "flutter_elinux_\(FlutterBackend)",
]
#endif

// FIXME: separate settings
let FlutterUnsafeCCompilerFlags = FlutterUnsafeCxxCompilerFlags

let package = Package(
    name: "FlutterSwift",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "FlutterSwift", targets: ["FlutterSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.0.0"),
    ],
    targets: [
        .target(
            name: "CxxFlutterSwift",
            dependencies: [],
            cSettings: [
                .unsafeFlags(FlutterUnsafeCCompilerFlags),
            ],
            cxxSettings: [
                .unsafeFlags(FlutterUnsafeCxxCompilerFlags),
            ],
            linkerSettings: [
                .unsafeFlags(FlutterUnsafeLinkerFlags),
            ]
        ),
        .target(
            name: "FlutterSwift",
            dependencies: [
                .target(name: "CxxFlutterSwift", condition: .when(platforms: [.linux])),
                "AnyCodable",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            cSettings: [
                .unsafeFlags(FlutterUnsafeCCompilerFlags),
            ],
            cxxSettings: [
                .unsafeFlags(FlutterUnsafeCxxCompilerFlags),
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
                .unsafeFlags(FlutterUnsafeCCompilerFlags),
            ],
            cxxSettings: [
                .unsafeFlags(FlutterUnsafeCxxCompilerFlags),
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
    ],
    cLanguageStandard: .c17
    // cxxLanguageStandard: .cxx17
)
