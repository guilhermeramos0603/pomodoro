import AppKit

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.count > i + 1 {
    let width = CommandLine.arguments.count > i + 2 ? Double(CommandLine.arguments[i + 2]) ?? 250 : 250
    Snapshot.run(path: CommandLine.arguments[i + 1], width: width)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory: menu bar item only, no Dock icon, no main menu.
app.setActivationPolicy(.accessory)
app.run()
