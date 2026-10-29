import Foundation
import CoreGraphics

enum PopupGeometry {
    static let defaultSize = CGSize(width: 480, height: 400)
    static let minimumSize = CGSize(width: 360, height: 240)

    static func restore(_ saved: CGRect?, screens: [CGRect], pointer: CGPoint) -> CGRect {
        guard let saved, isUsable(saved) else {
            return nearPointer(size: defaultSize, screens: screens, pointer: pointer)
        }
        let screens = screens.filter(isUsable)
        let overlapping = screens.max { intersectionArea(saved, $0) < intersectionArea(saved, $1) }
        let screen = overlapping.flatMap { intersectionArea(saved, $0) > 0 ? $0 : nil }
            ?? screen(at: pointer, in: screens)
        guard let screen else { return saved }
        return clamp(saved, to: screen)
    }

    static func nearPointer(size: CGSize, screens: [CGRect], pointer: CGPoint) -> CGRect {
        let frame = CGRect(x: pointer.x + 16, y: pointer.y - size.height - 16,
                           width: size.width, height: size.height)
        guard let screen = screen(at: pointer, in: screens.filter(isUsable)) else { return frame }
        return clamp(frame, to: screen)
    }

    static func isUsable(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.width, frame.height, frame.maxX, frame.maxY]
            .allSatisfy(\.isFinite) && frame.width > 0 && frame.height > 0
    }

    static func nearSelection(_ selection: CGRect?, size: CGSize, screens: [CGRect], pointer: CGPoint) -> CGRect {
        guard let selection, isUsable(selection),
              let screen = screens.filter(isUsable).max(by: { intersectionArea(selection, $0) < intersectionArea(selection, $1) }),
              intersectionArea(selection, screen) > 0 else {
            return nearPointer(size: size, screens: screens, pointer: pointer)
        }
        let candidates = [
            CGRect(x: selection.maxX + 16, y: selection.maxY - size.height, width: size.width, height: size.height),
            CGRect(x: selection.minX - size.width - 16, y: selection.maxY - size.height, width: size.width, height: size.height),
            CGRect(x: selection.minX, y: selection.minY - size.height - 16, width: size.width, height: size.height),
            CGRect(x: selection.minX, y: selection.maxY + 16, width: size.width, height: size.height)
        ].map { clamp($0, to: screen) }
        return candidates.first(where: { !$0.intersects(selection) })
            ?? candidates.min(by: { intersectionArea($0, selection) < intersectionArea($1, selection) })!
    }

    private static func screen(at point: CGPoint, in screens: [CGRect]) -> CGRect? {
        screens.first(where: { $0.contains(point) }) ?? screens.first
    }

    private static func intersectionArea(_ frame: CGRect, _ screen: CGRect) -> CGFloat {
        let intersection = frame.intersection(screen)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func clamp(_ frame: CGRect, to screen: CGRect) -> CGRect {
        let width = min(max(frame.width, minimumSize.width), screen.width)
        let height = min(max(frame.height, minimumSize.height), screen.height)
        return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - height),
                      width: width, height: height)
    }
}
