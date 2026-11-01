import Foundation
import CoreGraphics
import Testing
@testable import KotoFloatKit

struct PopupGeometryTests {
    let main = CGRect(x: 0, y: 40, width: 1440, height: 860)
    let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)

    @Test func fitsContentFromCompactToTallWithoutMovingTheTopEdge() {
        let initial = CGRect(x: 100, y: 600, width: 480, height: 200)
        let cases: [(CGFloat, CGFloat)] = [(90, 160), (280, 280), (420, 420), (900, 600)]
        for (content, height) in cases {
            let fitted = PopupGeometry.fittingContentHeight(content, to: initial, screens: [main], pointer: .zero)
            #expect(fitted.height == height)
            #expect(fitted.maxY == 800)
            #expect(fitted.minX == 100)
            #expect(fitted.width == 480)
        }
    }

    @Test func newShortContentShrinksPreviouslyTallSavedFrame() {
        let tall = CGRect(x: 100, y: 200, width: 620, height: 600)
        let fitted = PopupGeometry.fittingContentHeight(170, to: tall, screens: [main], pointer: .zero)
        #expect(fitted == CGRect(x: 100, y: 630, width: 620, height: 170))
    }

    @Test func openingPlacementUsesCompactHeightBeforePointerAndSelectionPlacement() {
        let saved = CGRect(x: 100, y: 100, width: 480, height: 600)
        let pointer = CGPoint(x: 400, y: 500)
        let selection = CGRect(x: 100, y: 550, width: 200, height: 30)
        #expect(PopupGeometry.openingFrame(saved, placement: .nearPointer, selectionBounds: nil,
            screens: [main], pointer: pointer) == CGRect(x: 416, y: 284, width: 480, height: 200))
        #expect(PopupGeometry.openingFrame(saved, placement: .nearSelection, selectionBounds: selection,
            screens: [main], pointer: pointer) == CGRect(x: 316, y: 380, width: 480, height: 200))
        #expect(PopupGeometry.openingFrame(saved, placement: .previousPosition, selectionBounds: nil,
            screens: [main], pointer: pointer) == CGRect(x: 100, y: 500, width: 480, height: 200))
    }

    @Test func contentFittingRespectsDisplayCapAndRecoversFromOffscreenAnchor() {
        let screen = CGRect(x: -1000, y: 50, width: 1000, height: 700)
        let frame = CGRect(x: -400, y: 20, width: 480, height: 200)
        let fitted = PopupGeometry.fittingContentHeight(1000, to: frame, screens: [screen], pointer: .zero)
        #expect(fitted.height == 490)
        #expect(screen.contains(fitted))
    }

    @Test func contentFittingRejectsInvalidMeasurementsAndStillCapsWithoutScreens() {
        let frame = CGRect(x: 100, y: 600, width: 480, height: 200)
        for value in [CGFloat.nan, .infinity, -10] {
            #expect(PopupGeometry.fittingContentHeight(value, to: frame, screens: [main], pointer: .zero) == frame)
        }
        #expect(PopupGeometry.fittingContentHeight(2000, to: frame, screens: [], pointer: .zero).height == 600)
    }

    @Test func toolbarClearsAllNativeButtonsIncludingWiderSystemLayouts() {
        let buttons = [CGRect(x: 12, y: 10, width: 14, height: 14),
                       CGRect(x: 40, y: 10, width: 14, height: 14),
                       CGRect(x: 88, y: 10, width: 22, height: 22)]
        let inset = PopupGeometry.toolbarLeadingInset(for: buttons)
        #expect(inset == 122)
        #expect(buttons.allSatisfy { inset >= $0.maxX + 12 })
        #expect(PopupGeometry.toolbarLeadingInset(for: []) == 88)
    }

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
        let result = PopupGeometry.restore(saved, screens: [main], pointer: .zero)
        #expect(main.contains(result))
        #expect(result.width == 1440)
        #expect(result.height == 600)
    }

    @Test func capsHeightToSeventyPercentOnShorterDisplaysAcrossPlacements() {
        let screen = CGRect(x: -1000, y: 50, width: 1000, height: 700)
        let size = CGSize(width: 480, height: 900)
        let pointer = CGPoint(x: -800, y: 600)
        let selection = CGRect(x: -900, y: 500, width: 120, height: 24)
        let frames = [
            PopupGeometry.restore(CGRect(origin: pointer, size: size), screens: [screen], pointer: pointer),
            PopupGeometry.nearPointer(size: size, screens: [screen], pointer: pointer),
            PopupGeometry.nearSelection(selection, size: size, screens: [screen], pointer: pointer)
        ]
        for frame in frames {
            #expect(frame.height == 490)
            #expect(screen.contains(frame))
        }
        #expect(frames[1].maxY == 584)
    }

    @Test func preservesInteractiveMinimumOnShortButUsableDisplay() {
        let screen = CGRect(x: 0, y: 0, width: 500, height: 200)
        let result = PopupGeometry.restore(nil, screens: [screen], pointer: .zero)
        #expect(result.height == 160)
        #expect(screen.contains(result))
    }

    @Test func allowsSmallUsableScreenWithoutOverflow() {
        let small = CGRect(x: 0, y: 0, width: 320, height: 120)
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
            #expect(result == CGRect(x: 416, y: 384, width: 480, height: 200))
        }
    }

    @Test func expandsUndersizedSavedFrame() {
        let saved = CGRect(x: 100, y: 100, width: 20, height: 30)
        #expect(PopupGeometry.restore(saved, screens: [main], pointer: .zero)
            == CGRect(x: 100, y: 100, width: 360, height: 160))
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
