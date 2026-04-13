// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PhoneticsMaestro",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PhoneticsMaestro",
            targets: ["PhoneticsMaestro"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "PhoneticsMaestro",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "PhoneticsMaestro",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "PhoneticsMaestroTests",
            dependencies: ["PhoneticsMaestro"],
            path: "PhoneticsMaestroTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ]
)
