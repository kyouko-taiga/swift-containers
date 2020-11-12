// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "swift-containers",
  products: [
    .executable(name: "Driver", targets: ["Driver"]),
    .library(name: "Containers",targets: ["Containers"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "Driver", dependencies: ["Containers"]),
    .target(name: "Containers", dependencies: []),
    .testTarget(name: "ContainersTests", dependencies: ["Containers"]),
  ]
)
