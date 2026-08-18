#if DEBUG
import Foundation

/// Launch arguments used to jump straight to a screen state when capturing
enum DebugLaunchOptions {
    static var popup: MainMenuViewModel.Popup? {
        value(for: "-debugPopup").flatMap(MainMenuViewModel.Popup.init(rawValue:))
    }

    /// Starts a session on its own once the menu settles, for capturing the
    /// curtain-opening transition: `-debugAutoStart`.
    static var autoStartsSession: Bool {
        arguments.contains("-debugAutoStart")
    }

    /// Logs the player's joints in pose-definition coordinates once a second,
    /// which is how a new pose gets recorded: `-debugPrintPose`.
    static var printsPoseCoordinates: Bool {
        arguments.contains("-debugPrintPose")
    }

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }
}
#endif
