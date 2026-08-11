import Foundation
import SwiftUI

/// The three text sizes a resident can choose on the Hub.
///
/// Deliberately three named steps rather than a slider: a slider asks someone
/// with a tremor to land on a value, and it gives no way to say "put it back
/// how it was". Every step is still at or above the 21pt floor `HubFont`
/// already sets, so no choice here can make the Hub less readable than it
/// ships.
enum HubTextScale: String, CaseIterable, Identifiable {
    case standard
    case large
    case largest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .large: return "Large"
        case .largest: return "Largest"
        }
    }

    /// Applied by `HubFont` to every size it returns.
    var multiplier: CGFloat {
        switch self {
        case .standard: return 1.0
        case .large: return 1.15
        case .largest: return 1.3
        }
    }
}

/// Holds the resident's chosen text size and persists it.
///
/// Stored per device rather than per user: a Hub phone is bound to one room,
/// and the person who set the size is the person who will read it. Signing a
/// device out and back in must not silently shrink the type back down.
///
/// `HubFont` reads `HubTextSize.multiplier` on every call, so changing `scale`
/// re-sizes the whole Hub. SwiftUI only redraws views that observe this
/// object, which is why both `HubRootView` and the settings screen hold an
/// `@ObservedObject` on it — that covers the resident's own surface and the
/// live preview on the settings screen itself.
final class HubTextSize: ObservableObject {
    static let shared = HubTextSize()

    private static let storageKey = "meridian.hub.textScale"

    @Published var scale: HubTextScale {
        didSet {
            guard scale != oldValue else { return }
            UserDefaults.standard.set(scale.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        scale = stored.flatMap(HubTextScale.init(rawValue:)) ?? .standard
    }

    /// Read by every `HubFont` call. A plain static lookup rather than an
    /// environment value because `HubFont`'s members are static functions
    /// called from ~40 places; threading an environment value through all of
    /// them would touch every Hub view for no behavioural gain.
    static var multiplier: CGFloat { shared.scale.multiplier }
}
