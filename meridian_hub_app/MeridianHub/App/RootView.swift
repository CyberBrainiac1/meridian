import SwiftUI

/// Deliberately thin. Unlike Care and Family there is no tab bar here: a
/// resident device shows one surface and stays on it, so everything the
/// resident sees lives in HubSurfaceView.
struct RootView: View {
    let profile: HubProfile

    var body: some View {
        HubSurfaceView(profile: profile)
    }
}
