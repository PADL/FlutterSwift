// swift-tools-version:5.7

import PackageDescription
import Foundation

#if os(macOS)
let FlutterRoot = "/opt/flutter"
let FlutterLibPath = "\(FlutterRoot)/bin/cache/artifacts/engine/darwin-x64-release"
let FlutterIncludePath = ""
let FlutterBackend = ""
let FlutterUnsafeCompilerFlags = [String:String]()
let FlutterUnsafeLinkerFlags = [
    "-Xlinker", "-F",
    "-Xlinker", FlutterLibPath,
    "-Xlinker", "-framework",
    "-Xlinker", "FlutterMacOS",
    ]
#elseif os(Linux)
let FlutterRoot = "/opt/elinux"
let FlutterLibPath = "\(FlutterRoot)/lib"
let FlutterIncludePath = "\(FlutterRoot)/include"
let FlutterBackend = "x11"
let FlutterUnsafeCCompilerFlags = [
    "-I", FlutterIncludePath,
    ]
let FlutterUnsafeCXXCompilerFlags = [
    "-I", FlutterIncludePath,
    ]
let FlutterUnsafeLinkerFlags = [
    "-Xlinker", "-L", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-rpath", "-Xlinker", FlutterLibPath,
    "-Xlinker", "-l", "-Xlinker", "flutter_elinux_\(FlutterBackend)"
    ]
#endif

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
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.0.0")
    ],
    targets: [
        .target(
            name: "CFlutterSwift",
            dependencies: [],
            cxxSettings: [
                .unsafeFlags(FlutterUnsafeCXXCompilerFlags)
            ],
            linkerSettings: [
                .unsafeFlags(FlutterUnsafeLinkerFlags)
            ]
        ),
	.target(
	    name: "FlutterSwift",
	    dependencies: [
		"AnyCodable",
		"CFlutterSwift",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
	    ],
            cSettings: [
                .unsafeFlags(FlutterUnsafeCCompilerFlags)
            ],
            linkerSettings: [
                .unsafeFlags(FlutterUnsafeLinkerFlags)
            ]
	),
        .testTarget(
            name: "FlutterSwiftTests",
            dependencies: [
                .target(name: "FlutterSwift"),
            ],
            cSettings: [
                .unsafeFlags(FlutterUnsafeCCompilerFlags)
            ],
            linkerSettings: [
                .unsafeFlags(FlutterUnsafeLinkerFlags)
            ]
        ),
    ]
)
