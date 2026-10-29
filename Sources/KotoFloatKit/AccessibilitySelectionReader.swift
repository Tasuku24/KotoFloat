import AppKit
import ApplicationServices

struct SelectionAttributes {
    var isProtected = false
    var text: String?
    var range: CFRange?
    var bounds: CGRect?

    var selection: SelectionRead {
        if isProtected { return .protectedField }
        if let range, range.length == 0 { return .empty }
        guard let text else { return .unavailable }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        return .selected(text, bounds.flatMap { PopupGeometry.isUsable($0) ? $0 : nil })
    }
}

enum SelectionCoordinates {
    static func appKitRect(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect? {
        guard PopupGeometry.isUsable(rect), primaryScreenHeight.isFinite else { return nil }
        return CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}

@MainActor
enum AccessibilitySelectionReader {
    static func focusedElement(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let value = attribute(kAXFocusedUIElementAttribute, of: app),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.2)
        return element
    }

    static func read(pid: pid_t) -> SelectionRead {
        guard let element = focusedElement(pid: pid) else { return .unavailable }
        var ancestor: AXUIElement? = element
        for _ in 0..<5 {
            guard let current = ancestor else { break }
            if attribute(kAXSubroleAttribute, of: current) as? String == kAXSecureTextFieldSubrole {
                return .protectedField
            }
            guard let parent = attribute(kAXParentAttribute, of: current),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            ancestor = (parent as! AXUIElement)
        }
        var attributes = SelectionAttributes()
        attributes.text = attribute(kAXSelectedTextAttribute, of: element) as? String
        if let value = attribute(kAXSelectedTextRangeAttribute, of: element),
           CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .cfRange {
            var range = CFRange()
            if AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 {
                attributes.range = range
                var rawBounds: CFTypeRef?
                if range.length > 0,
                   AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                       value, &rawBounds) == .success,
                   let rawBounds, CFGetTypeID(rawBounds) == AXValueGetTypeID(),
                   AXValueGetType(rawBounds as! AXValue) == .cgRect {
                    var rect = CGRect.zero
                    if AXValueGetValue(rawBounds as! AXValue, .cgRect, &rect), let primary = NSScreen.screens.first {
                        attributes.bounds = SelectionCoordinates.appKitRect(rect, primaryScreenHeight: primary.frame.height)
                    }
                }
            }
        }
        return attributes.selection
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
}
