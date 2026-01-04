// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TalkFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TalkFlow", targets: ["TalkFlow"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "TalkFlow",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "TalkFlow",
            exclude: [
                "Resources/Info.plist",
                "Resources/TalkFlow.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "TalkFlowTests",
            dependencies: ["TalkFlow"],
            path: "TalkFlowTests"
        )
    ]
)
