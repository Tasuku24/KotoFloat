import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class SystemCaptureEnvironment: CaptureEnvironment {
    private let copyGate = CopyRequestGate()
    var isTrusted: Bool { AXIsProcessTrusted() }

    func currentSource() -> SourceApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return SourceApplication(processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier, name: app.localizedName ?? L10n.text("capture.unknownSource"))
    }

    func readSelection(from source: SourceApplication) -> SelectionRead {
        AccessibilitySelectionReader.read(pid: source.processIdentifier)
    }

    func copySelection(from source: SourceApplication) async throws -> String {
        try await copyGate.run {
            let session = SystemCopySession(source: source)
            return try await ClipboardCapture(clipboard: SystemClipboard()).capture(session: session)
        }
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
private final class SystemCopySession: CopySession {
    private static let eventTag: Int64 = 0x4B6F746F466C6F61
    private let source: SourceApplication
    private let focusedElement: AXUIElement?
    private var monitor: Any?
    private var activationObserver: NSObjectProtocol?
    private(set) var interrupted = false

    init(source: SourceApplication) {
        self.source = source
        focusedElement = AccessibilitySelectionReader.focusedElement(pid: source.processIdentifier)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { [weak self] event in
            MainActor.assumeIsolated {
                if event.cgEvent?.getIntegerValueField(.eventSourceUserData) != Self.eventTag {
                    self?.interrupted = true
                }
            }
        }
        if monitor == nil { interrupted = true }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.interrupted = true }
        }
    }

    var sourceIsCurrent: Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == source.processIdentifier else { return false }
        if let focusedElement {
            guard let current = AccessibilitySelectionReader.focusedElement(pid: source.processIdentifier) else { return false }
            return CFEqual(focusedElement, current)
        }
        return true
    }

    var modifiersReleased: Bool {
        CGEventSource.flagsState(.combinedSessionState).intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
    }

    func sendCopy() -> Bool {
        guard sourceIsCurrent, !interrupted, modifiersReleased,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return false }
        for event in [down, up] {
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
            event.postToPid(self.source.processIdentifier)
        }
        return true
    }

    func finish() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        monitor = nil
        activationObserver = nil
    }
}
