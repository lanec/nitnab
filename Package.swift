// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NitNab",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "NitNabLib",
            targets: ["NitNabLib"]
        )
    ],
    targets: [
        .target(
            name: "NitNabLib",
            path: "NitNab",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "NitNab.entitlements",
                "NitNabApp.swift",
                "create_project.sh"
            ]
        ),
        .testTarget(
            name: "NitNabLibTests",
            dependencies: ["NitNabLib"]
        )
    ]
)
