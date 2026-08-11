import SwiftUI

/// Deliberately thin. Unlike Care and Family there is no tab bar here: a
/// resident device shows one surface and stays on it, so everything the
/// resident sees lives in HubSurfaceView.
struct HubRootView: View {
    let profile: HubProfile

    /// Observed but never read here. `HubFont` multiplies every size by
    /// `HubTextSize.multiplier`, which is a plain static lookup — SwiftUI has
    /// no way to know a view depends on it. Holding the object at the root
    /// means changing the text size in Settings redraws the whole resident
    /// surface immediately, rather than whenever some unrelated state happens
    /// to change next.
    @ObservedObject private var textSize = HubTextSize.shared

    var body: some View {
        HubSurfaceView(profile: profile)
    }
}
