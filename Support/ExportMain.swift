import AppKit

@main
enum Export {
    static func main() {
        let dir = CommandLine.arguments.dropFirst().first ?? "/tmp/AppIcon.iconset"
        let url = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for (pixels, name) in sizes {
            let data = MenuIcon.appIconPixels(pixels)
            try! data.write(to: url.appendingPathComponent(name))
        }
        FileHandle.standardOutput.write(Data("wrote \(dir)\n".utf8))
    }
}
