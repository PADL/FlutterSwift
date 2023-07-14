// swift-tools-version:5.5

import PackageDescription
import Foundation

let FlutterRoot = "/opt/flutter"
let FlutterFrameworkPath = "\(FlutterRoot)/bin/cache/artifacts/engine/darwin-x64-release"

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
	    name: "FlutterSwift",
	    dependencies: [
		"AnyCodable",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
	    ],
            linkerSettings: [
                .linkedFramework("FlutterMacOS"),
                .unsafeFlags(["-Xlinker", "-F", "-Xlinker", FlutterFrameworkPath]),
            ]
	),
        .testTarget(
            name: "FlutterSwiftTests",
            dependencies: [
                .target(name: "FlutterSwift"),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", FlutterFrameworkPath]),
            ]
        ),
    ]
)
