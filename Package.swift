// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "InBodyMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "InBodyKit"),
        .executableTarget(name: "inbody", dependencies: ["InBodyKit"]),
        .executableTarget(name: "OpenBody", dependencies: ["InBodyKit"], path: "Sources/InBodyApp",
                          resources: [.process("Resources")]),
    ]
)
