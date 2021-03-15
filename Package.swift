// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "questdb-nio",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "QuestDB",
      targets: ["QuestDB"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
  ],
  targets: [
    .target(
      name: "QuestDB",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client")
      ]
    ),
    .testTarget(
      name: "QuestDBTests",
      dependencies: ["QuestDB"]
    ),
  ]
)
