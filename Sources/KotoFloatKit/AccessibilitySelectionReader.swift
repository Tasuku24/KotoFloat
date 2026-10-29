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
struct AccessibilityAttributes {
    var read: (AXUIElement, String) -> (AXError, CFTypeRef?) = { element, name in
        AXUIElementSetMessagingTimeout(element, 0.2)
        var result: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &result)
        return (status, result)
    }

    func value(_ name: String, of element: AXUIElement) throws -> CFTypeRef? {
        let (status, result) = read(element, name)
        switch status {
        case .success: return result
        case .attributeUnsupported, .noValue: return nil
        case .apiDisabled: throw CaptureFailure.permissionRequired
        default: throw CaptureFailure.appUnavailable
        }
    }
}

@MainActor
enum AccessibilitySelectionReader {
    static func focusedElement(pid: pid_t, attributes: AccessibilityAttributes = AccessibilityAttributes()) throws -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let value = try attributes.value(kAXFocusedUIElementAttribute, of: app),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.2)
        return element
    }

    static func read(pid: pid_t, access: AccessibilityAttributes = AccessibilityAttributes()) -> SelectionRead {
        do {
            guard let element = try focusedElement(pid: pid, attributes: access) else { return .failed(.appUnavailable) }
            var ancestor: AXUIElement? = element
            for _ in 0..<5 {
                guard let current = ancestor else { break }
                if try access.value(kAXSubroleAttribute, of: current) as? String == kAXSecureTextFieldSubrole {
                    return .protectedField
                }
                guard let parent = try access.value(kAXParentAttribute, of: current),
                      CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
                ancestor = (parent as! AXUIElement)
            }
            var attributes = SelectionAttributes()
            attributes.text = try access.value(kAXSelectedTextAttribute, of: element) as? String
            if let value = try access.value(kAXSelectedTextRangeAttribute, of: element),
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
        } catch {
            return .failed(error as? CaptureFailure ?? .appUnavailable)
        }
    }
}
