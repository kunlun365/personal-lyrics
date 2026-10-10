// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "歌词精灵",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "歌词精灵",
            path: "Sources/MacSpotifyLyrics"
        )
    ]
)
