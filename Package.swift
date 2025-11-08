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
        .package(url: "https://github.com/automerge/automerge-swift.git", from: "0.6.1")
    ],
    targets: [
        .target(
            name: "CommonplaceBook",
            dependencies: [
                "Yams",
                .product(name: "Automerge", package: "automerge-swift")
            ],
            path: "Template App",
            exclude: [
                "App/Template_AppApp.swift",
                "App/SceneDelegate.swift",
                "Features",
                "Resources"
            ]
        ),
        .testTarget(
            name: "CommonplaceBookTests",
            dependencies: ["CommonplaceBook"],
            path: "Template AppTests"
        ),
    ]
)
