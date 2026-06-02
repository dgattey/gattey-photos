import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// Drives the live "Gattey Photos" macOS window for toolbar/scroll-edge verification.
// Works across Spaces: window lookup + Accessibility scrolling, no coordinate hit-testing.
//   gptoolbar info            -> prints "<mainWindowID> <pid>"
//   gptoolbar scroll <frac>   -> sets the grid scroll position to frac in 0...1

func mainWindow() -> (id: Int, pid: pid_t)? {
    let opts = CGWindowListOption(arrayLiteral: .optionAll)
    guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return nil }
    var best: (id: Int, pid: pid_t, area: Double)?
    for w in info {
        guard let owner = w[kCGWindowOwnerName as String] as? String, owner.contains("Gattey") else { continue }
        guard let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
        let area = ((b["Width"] as? Double) ?? 0) * ((b["Height"] as? Double) ?? 0)
        let id = (w[kCGWindowNumber as String] as? Int) ?? -1
        let pid = pid_t((w[kCGWindowOwnerPID as String] as? Int) ?? 0)
        if best == nil || area > best!.area { best = (id, pid, area) }
    }
    guard let best else { return nil }
    return (best.id, best.pid)
}

func attr(_ el: AXUIElement, _ n: String) -> AnyObject? {
    var v: AnyObject?; AXUIElementCopyAttributeValue(el, n as CFString, &v); return v
}
func role(_ el: AXUIElement) -> String { (attr(el, kAXRoleAttribute) as? String) ?? "" }
func children(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }

func activate(pid: pid_t) {
    if let app = NSRunningApplication(processIdentifier: pid) {
        app.activate(options: [.activateAllWindows])
    }
}

func scrollAreas(pid: pid_t) -> [AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    var areas: [AXUIElement] = []
    func walk(_ el: AXUIElement, _ d: Int) {
        if role(el) == "AXScrollArea" { areas.append(el) }
        if d > 60 { return }
        for c in children(el) { walk(c, d + 1) }
    }
    walk(app, 0)
    return areas
}

func scroll(pid: pid_t, frac: Double) {
    // The SwiftUI scroll area only realizes its AX tree once the app is active and on-screen.
    activate(pid: pid)
    var areas: [AXUIElement] = []
    for _ in 0..<20 {
        areas = scrollAreas(pid: pid)
        if !areas.isEmpty { break }
        usleep(150000)
    }
    for sa in areas {
        if let vb = attr(sa, kAXVerticalScrollBarAttribute) {
            AXUIElementSetAttributeValue(vb as! AXUIElement, kAXValueAttribute as CFString, frac as CFTypeRef)
        }
    }
    FileHandle.standardError.write("scrollAreas=\(areas.count)\n".data(using: .utf8)!)
}

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write("usage: gptoolbar info|scroll <frac>\n".data(using: .utf8)!); exit(2) }
guard let win = mainWindow() else { FileHandle.standardError.write("no Gattey Photos window\n".data(using: .utf8)!); exit(1) }
switch args[1] {
case "info":
    print("\(win.id) \(win.pid)")
case "scroll":
    let frac = Double(args.count > 2 ? args[2] : "0") ?? 0
    scroll(pid: win.pid, frac: frac)
    print("scrolled \(frac)")
default:
    FileHandle.standardError.write("unknown command\n".data(using: .utf8)!); exit(2)
}
