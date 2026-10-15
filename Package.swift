// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Skellige",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "skellige", targets: ["IslandStackCLI"])
  ],
  targets: [
    .target(name: "IslandStackCore"),
    .executableTarget(name: "IslandStackCLI", dependencies: ["IslandStackCore"]),
    .testTarget(name: "IslandStackCoreTests", dependencies: ["IslandStackCore"])
  ]
)
