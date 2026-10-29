import SwiftUI

struct AccessibilityPermissionView: View {
    @State private var isGranted = SystemCaptureEnvironment().isTrusted
    @State private var checkedAt: Date?
    @State private var checkCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.text(isGranted ? "permission.granted" : "permission.required"),
                systemImage: isGranted ? "checkmark.circle" : "lock")
            Text(L10n.text(permissionHintKey))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if !isGranted {
                    Button(L10n.text("permission.request")) {
                        SystemCaptureEnvironment.requestAccessibility()
                        refresh()
                    }
                }
                Button(L10n.text("permission.openSettings")) { SystemCaptureEnvironment.openAccessibilitySettings() }
                Button(L10n.text("permission.refresh")) { refresh(showResult: true) }
            }
            .controlSize(.small)
            Group {
                if let checkedAt {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(isGranted ? Color.green : Color.orange)
                            .symbolEffect(.bounce, value: checkCount)
                        Text(String(format: L10n.text(isGranted ? "permission.checkedGranted" : "permission.checkedRequired"),
                            checkedAt.formatted(date: .omitted, time: .standard)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("permissionCheckResult")
                } else {
                    Text(" ").font(.caption).accessibilityHidden(true)
                }
            }
            .frame(minHeight: 28, alignment: .topLeading)
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private var permissionHintKey: String {
        if #available(macOS 27, *) { return "permission.hint" }
        return "permission.legacyHint"
    }

    private func refresh(showResult: Bool = false) {
        let current = SystemCaptureEnvironment().isTrusted
        if current != isGranted { checkedAt = nil }
        isGranted = current
        if showResult {
            checkedAt = .now
            checkCount += 1
        }
    }
}
