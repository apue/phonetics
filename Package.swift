// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PhoneticsMaestro",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PhoneticsCore",
            targets: ["PhoneticsCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "PhoneticsCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "PhoneticsMaestro",
            sources: [
                "App/RootView.swift",
                "Models",
                "Services",
                "ViewModels",
                "Views"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "PhoneticsMaestroTests",
            dependencies: ["PhoneticsCore"],
            path: "PhoneticsMaestroTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"])
            ]
        )
    ]
)
