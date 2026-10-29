import AppKit
import KotoFloatKit

@main
enum KotoFloatApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = KotoFloatDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
