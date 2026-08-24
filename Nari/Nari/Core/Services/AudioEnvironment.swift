import SwiftUI

private struct AudioServiceKey: EnvironmentKey {
    static let defaultValue: AudioServicing = SilentAudioService()
}

extension EnvironmentValues {
    /// Injected once by `RootView` from `AppServices`, so any button anywhere
    /// can play its click without threading the service through every view.
    var audio: AudioServicing {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }
}
