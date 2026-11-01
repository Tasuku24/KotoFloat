import Foundation
import CoreGraphics

enum PopupGeometry {
    static let defaultSize = CGSize(width: 480, height: 200)
    static let minimumSize = CGSize(width: 360, height: 160)
    static let maximumHeight: CGFloat = 600

    static func openingFrame(_ saved: CGRect?, placement: PopupPlacement, selectionBounds: CGRect?, screens: [CGRect], pointer: CGPoint) -> CGRect {
        let saved = saved.flatMap { isUsable($0) ? $0 : nil }
        let size = CGSize(width: saved?.width ?? defaultSize.width, height: defaultSize.height)
        switch placement {
        case .previousPosition:
            let compact = saved.map { CGRect(x: $0.minX, y: $0.maxY - size.height, width: size.width, height: size.height) }
            return restore(compact, screens: screens, pointer: pointer)
        case .nearPointer:
            return nearPointer(size: size, screens: screens, pointer: pointer)
        case .nearSelection:
            return nearSelection(selectionBounds, size: size, screens: screens, pointer: pointer)
        }
    }

    static func fittingContentHeight(_ height: CGFloat, to frame: CGRect, screens: [CGRect], pointer: CGPoint) -> CGRect {
        guard height.isFinite, height >= 0, isUsable(frame) else { return restore(frame, screens: screens, pointer: pointer) }
        let screen = screen(for: frame, screens: screens, pointer: pointer)
        let limit = screen.map { maximumHeight(on: $0) } ?? maximumHeight
        let fittedHeight = min(max(ceil(height), minimumSize.height), limit)
        let fitted = CGRect(x: frame.minX, y: frame.maxY - fittedHeight, width: frame.width, height: fittedHeight)
        return screen.map { clamp(fitted, to: $0) } ?? fitted
    }

    static func toolbarLeadingInset(for buttons: [CGRect]) -> CGFloat {
        max(88, (buttons.filter(isUsable).map(\.maxX).max() ?? 0) + 12)
    }

    static func maximumHeight(on screen: CGRect) -> CGFloat {
        min(maximumHeight, max(minimumSize.height, screen.height * 7 / 10), screen.height)
    }

    static func screen(for frame: CGRect?, screens: [CGRect], pointer: CGPoint) -> CGRect? {
        let screens = screens.filter(isUsable)
        if let frame, let overlapping = screens.max(by: { intersectionArea(frame, $0) < intersectionArea(frame, $1) }),
           intersectionArea(frame, overlapping) > 0 { return overlapping }
        return screen(at: pointer, in: screens)
    }

    static func restore(_ saved: CGRect?, screens: [CGRect], pointer: CGPoint) -> CGRect {
        guard let saved, isUsable(saved) else {
            return nearPointer(size: defaultSize, screens: screens, pointer: pointer)
        }
        let screen = screen(for: saved, screens: screens, pointer: pointer)
        guard let screen else { return saved }
        return clamp(saved, to: screen)
    }

    static func nearPointer(size: CGSize, screens: [CGRect], pointer: CGPoint) -> CGRect {
        guard let screen = screen(at: pointer, in: screens.filter(isUsable)) else {
            return CGRect(x: pointer.x + 16, y: pointer.y - size.height - 16, width: size.width, height: size.height)
        }
        let size = boundedSize(size, to: screen)
        let frame = CGRect(x: pointer.x + 16, y: pointer.y - size.height - 16,
                           width: size.width, height: size.height)
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
        let size = boundedSize(size, to: screen)
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
        let size = boundedSize(frame.size, to: screen)
        return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - size.width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - size.height),
                      width: size.width, height: size.height)
    }

    private static func boundedSize(_ size: CGSize, to screen: CGRect) -> CGSize {
        CGSize(width: min(max(size.width, minimumSize.width), screen.width),
               height: min(max(size.height, minimumSize.height), maximumHeight(on: screen)))
    }
}
