// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cashew",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "cashew",
            targets: ["cashew"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
        .package(url: "https://github.com/pumperknickle/ArrayTrie.git", from: "0.0.9"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "4.0.0"),
        .package(url: "https://github.com/swift-libp2p/swift-cid.git", from: "0.0.4"),
        .package(url: "https://github.com/JohnSundell/CollectionConcurrencyKit.git", from: "0.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "cashew",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "ArrayTrie", package: "ArrayTrie"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
                .product(name: "CID", package: "swift-cid")]),
        .testTarget(
            name: "cashewTests",
            dependencies: ["cashew"]
        ),
    ]
)
