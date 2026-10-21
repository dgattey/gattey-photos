// DylApp.toml's icon generator: copies the committed Icon Composer bundle to build/AppIcon.icon, which devkit and
// release-kit compile with actool. Usage: swift scripts/link-app-icon.swift <repo-root>
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let build = root.appending(path: "build")
let icon = build.appending(path: "AppIcon.icon")
try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: icon)
try FileManager.default.copyItem(at: root.appending(path: "AppIcon.icon"), to: icon)
