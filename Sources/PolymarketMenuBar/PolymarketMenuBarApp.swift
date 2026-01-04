import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the Dock icon so this behaves like a menu bar-only app.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct PolymarketMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Polymarket", systemImage: "chart.line.uptrend.xyaxis") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
