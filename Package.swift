// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommonplaceBook",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CommonplaceBook",
            targets: ["CommonplaceBook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/automerge/automerge-swift.git", from: "0.6.1"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        .target(
            name: "CommonplaceBook",
            dependencies: [
                "Yams",
                .product(name: "Automerge", package: "automerge-swift"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Commonplace Book",
            exclude: [
                "App/Commonplace_BookApp.swift",
                "App/SceneDelegate.swift",
                "Features",
                "Resources"
            ]
        ),
        .testTarget(
            name: "CommonplaceBookTests",
            dependencies: ["CommonplaceBook"],
            path: "Commonplace BookTests"
        ),
    ]
)
