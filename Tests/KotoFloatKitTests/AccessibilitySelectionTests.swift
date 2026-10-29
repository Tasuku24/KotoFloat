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
