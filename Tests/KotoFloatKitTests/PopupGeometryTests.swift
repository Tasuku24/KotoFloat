import Foundation
import CoreGraphics
import Testing
@testable import KotoFloatKit

struct PopupGeometryTests {
    let main = CGRect(x: 0, y: 40, width: 1440, height: 860)
    let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)

    @Test func preservesUsableSavedFrameEvenWhenPointerMovesToAnotherDisplay() {
        let saved = CGRect(x: -1600, y: 200, width: 600, height: 500)
        #expect(PopupGeometry.restore(saved, screens: [main, left], pointer: .zero) == saved)
    }

    @Test func recoversWindowFromDisconnectedDisplay() {
        let saved = CGRect(x: 2200, y: 300, width: 600, height: 500)
        let result = PopupGeometry.restore(saved, screens: [main], pointer: CGPoint(x: 100, y: 200))
        #expect(main.contains(result))
        #expect(result.size == saved.size)
    }

    @Test func keepsTitleBarInsideUsableFrame() {
        let saved = CGRect(x: 1200, y: 800, width: 480, height: 400)
        #expect(PopupGeometry.restore(saved, screens: [main], pointer: .zero)
            == CGRect(x: 960, y: 500, width: 480, height: 400))
    }

    @Test func shrinksOversizedWindowToScreen() {
        let saved = CGRect(x: -100, y: -100, width: 3000, height: 2000)
        #expect(PopupGeometry.restore(saved, screens: [main], pointer: .zero) == main)
    }

    @Test func allowsSmallUsableScreenWithoutOverflow() {
        let small = CGRect(x: 0, y: 0, width: 320, height: 200)
        #expect(PopupGeometry.restore(nil, screens: [small], pointer: .zero) == small)
    }

    @Test func placesNearPointerOnNegativeCoordinateDisplay() {
        let result = PopupGeometry.nearPointer(size: CGSize(width: 480, height: 400),
            screens: [main, left], pointer: CGPoint(x: -1000, y: 800))
        #expect(result == CGRect(x: -984, y: 384, width: 480, height: 400))
    }

    @Test func clampsNearPointerAtBottomRightCorner() {
        let result = PopupGeometry.nearPointer(size: CGSize(width: 480, height: 400),
            screens: [main], pointer: CGPoint(x: 1439, y: 41))
        #expect(result == CGRect(x: 960, y: 40, width: 480, height: 400))
    }

    @Test func ignoresNonfiniteOrEmptySavedFrames() {
        for saved in [CGRect(x: CGFloat.nan, y: 0, width: 480, height: 400),
                      CGRect(x: 0, y: 0, width: 0, height: 0)] {
            let result = PopupGeometry.restore(saved, screens: [main], pointer: CGPoint(x: 400, y: 600))
            #expect(result == CGRect(x: 416, y: 184, width: 480, height: 400))
        }
    }

    @Test func expandsUndersizedSavedFrame() {
        let saved = CGRect(x: 100, y: 100, width: 20, height: 30)
        #expect(PopupGeometry.restore(saved, screens: [main], pointer: .zero)
            == CGRect(x: 100, y: 100, width: 360, height: 240))
    }

    @Test func placesBesideSelectionWithoutCoveringOriginal() {
        let selection = CGRect(x: 100, y: 550, width: 200, height: 30)
        let result = PopupGeometry.nearSelection(selection, size: CGSize(width: 480, height: 400),
            screens: [main], pointer: .zero)
        #expect(main.contains(result))
        #expect(!result.intersects(selection))
        #expect(result == CGRect(x: 316, y: 180, width: 480, height: 400))
    }

    @Test func selectionNearRightEdgeUsesSpaceToItsLeft() {
        let selection = CGRect(x: 1200, y: 500, width: 200, height: 30)
        let result = PopupGeometry.nearSelection(selection, size: CGSize(width: 480, height: 400),
            screens: [main], pointer: .zero)
        #expect(!result.intersects(selection))
        #expect(result == CGRect(x: 704, y: 130, width: 480, height: 400))
    }

    @Test func unavailableOrOffscreenSelectionFallsBackToPointer() {
        for selection in [nil, CGRect(x: 8000, y: 8000, width: 100, height: 20)] {
            #expect(PopupGeometry.nearSelection(selection, size: CGSize(width: 480, height: 400),
                screens: [main], pointer: CGPoint(x: 100, y: 800)) == CGRect(x: 116, y: 384, width: 480, height: 400))
        }
    }

    @Test func handlesTemporarilyMissingScreens() {
        let saved = CGRect(x: 100, y: 100, width: 480, height: 400)
        #expect(PopupGeometry.restore(saved, screens: [], pointer: .zero) == saved)
    }
}
