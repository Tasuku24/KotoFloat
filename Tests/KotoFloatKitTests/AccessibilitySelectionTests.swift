import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import KotoFloatKit

struct AccessibilitySelectionTests {
    @Test func protectedFieldWinsOverReportedText() {
        #expect(SelectionAttributes(isProtected: true, text: "secret").selection == .protectedField)
    }
    @Test func selectionAndBoundsArePreserved() {
        let rect = CGRect(x: -500, y: 1400, width: 200, height: 20)
        #expect(SelectionAttributes(text: "日本語 🌸", range: CFRange(location: 2, length: 6), bounds: rect).selection == .selected("日本語 🌸", rect))
    }
    @Test func knownZeroRangeDoesNotCopyWholeField() {
        #expect(SelectionAttributes(range: CFRange(location: 8, length: 0)).selection == .empty)
    }
    @Test func whitespaceIsEmptyButMissingAttributeAllowsFallback() {
        #expect(SelectionAttributes(text: " \n").selection == .empty)
        #expect(SelectionAttributes().selection == .unavailable)
    }
    @Test func unusableBoundsAreDiscardedWithoutLosingSelection() {
        #expect(SelectionAttributes(text: "selected", bounds: .zero).selection == .selected("selected", nil))
    }
    @Test func quartzSelectionCoordinatesFlipAroundPrimaryDisplay() {
        #expect(SelectionCoordinates.appKitRect(CGRect(x: -800, y: -300, width: 200, height: 40), primaryScreenHeight: 900) == CGRect(x: -800, y: 1160, width: 200, height: 40))
        #expect(SelectionCoordinates.appKitRect(.zero, primaryScreenHeight: 900) == nil)
    }
}

@MainActor struct AccessibilityFailureTests {
    @Test(arguments: [kAXFocusedUIElementAttribute, kAXSelectedTextAttribute])
    func timedOutAttributeNeverTriggersCopy(_ failedAttribute: String) async {
        let element = AXUIElementCreateApplication(42)
        let access = AccessibilityAttributes(read: { _, name in
            if name == failedAttribute { return (.cannotComplete, nil) }
            if name == kAXFocusedUIElementAttribute { return (.success, element) }
            return (.attributeUnsupported, nil)
        })
        let env = CaptureEnvironmentStub()
        env.selection = AccessibilitySelectionReader.read(pid: 42, access: access)
        #expect(env.selection == .failed(.appUnavailable))
        await #expect(throws: CaptureFailure.appUnavailable) { try await SelectionCapture(environment: env).capture() }
        #expect(env.copies == 0)
    }

    @Test(arguments: [AXError.apiDisabled, .invalidUIElement])
    func permissionAndInvalidElementErrorsStopCapture(_ error: AXError) {
        let access = AccessibilityAttributes(read: { _, _ in (error, nil) })
        let expected: CaptureFailure = error == .apiDisabled ? .permissionRequired : .appUnavailable
        #expect(AccessibilitySelectionReader.read(pid: 42, access: access) == .failed(expected))
    }

    @Test func unsupportedSelectedTextStillAllowsCopyFallback() {
        let element = AXUIElementCreateApplication(42)
        let access = AccessibilityAttributes(read: { _, name in
            name == kAXFocusedUIElementAttribute ? (.success, element) : (.attributeUnsupported, nil)
        })
        #expect(AccessibilitySelectionReader.read(pid: 42, access: access) == .unavailable)
    }
}
