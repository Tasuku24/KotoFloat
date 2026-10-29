import Foundation
import CoreGraphics
import Observation

enum PopupPlacement: String, CaseIterable {
    case previousPosition
    case nearPointer
}

@MainActor @Observable
final class PopupPreferences {
    @ObservationIgnored private let defaults: UserDefaults
    var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: "popup.alwaysOnTop") }
    }
    var placement: PopupPlacement {
        didSet { defaults.set(placement.rawValue, forKey: "popup.placement") }
    }
    var savedFrame: CGRect? {
        get {
            guard let data = defaults.data(forKey: "popup.frame.v1"),
                  let frame = try? JSONDecoder().decode(CGRect.self, from: data),
                  PopupGeometry.isUsable(frame) else { return nil }
            return frame
        }
        set {
            guard let frame = newValue, PopupGeometry.isUsable(frame),
                  let data = try? JSONEncoder().encode(frame) else {
                defaults.removeObject(forKey: "popup.frame.v1")
                return
            }
            defaults.set(data, forKey: "popup.frame.v1")
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        alwaysOnTop = defaults.object(forKey: "popup.alwaysOnTop") as? Bool ?? true
        placement = defaults.string(forKey: "popup.placement").flatMap(PopupPlacement.init(rawValue:))
            ?? .previousPosition
    }
}
