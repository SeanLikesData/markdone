// swift-tools-version:5.9
import PackageDescription

// Kept only for editor/structure reference. The app is built with build.sh
// (swiftc directly), because Swift Package Manager's manifest step does not
// link on a machine that has only the Xcode Command Line Tools.
let package = Package(
    name: "Taskdown",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Taskdown",
            path: "Sources/Taskdown"
        )
    ]
)
