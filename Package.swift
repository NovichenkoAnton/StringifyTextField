// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "StringifyTextField",
    products: [
        .library(
            name: "StringifyTextField",
            targets: ["StringifyTextField"]),
    ],
    dependencies: [
        .package(url: "https://github.com/NovichenkoAnton/Extendy.git", .upToNextMajor(from: "1.1.4")),
    ],
    targets: [
        .target(
            name: "StringifyTextField",
            dependencies: [
                "Extendy"
            ],
            path: "Sources"
        )
    ]
)
