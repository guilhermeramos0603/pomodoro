import AppKit

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.count > i + 1 {
    let width = CommandLine.arguments.count > i + 2 ? Double(CommandLine.arguments[i + 2]) ?? 250 : 250
    let height = CommandLine.arguments.count > i + 3 ? Double(CommandLine.arguments[i + 3]) : nil
    Snapshot.run(path: CommandLine.arguments[i + 1], width: width, height: height.map { CGFloat($0) })
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: menu bar item only, no Dock icon, no main menu.
app.setActivationPolicy(.accessory)
app.run()
